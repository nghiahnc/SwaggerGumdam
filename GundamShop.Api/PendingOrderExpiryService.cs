using GundamShop.Bll;
using GundamShop.Dal;
using Microsoft.EntityFrameworkCore;

namespace GundamShop.Api;

public class PendingOrderExpiryService(IServiceScopeFactory scopes, ILogger<PendingOrderExpiryService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                List<Guid> due;
                using (var scope = scopes.CreateScope())
                {
                    var db = scope.ServiceProvider.GetRequiredService<ShopDbContext>();
                    due = await db.Orders.Where(o => o.Status == "PendingPayment" && o.ExpiresAtUtc <= DateTime.UtcNow)
                        .OrderBy(o => o.ExpiresAtUtc).Select(o => o.Id).Take(100).ToListAsync(stoppingToken);
                }
                // One scope per order: closing a Stripe page can take seconds, so vouchers and orders read
                // for an earlier order would be stale by the time a later one is released.
                foreach (var id in due)
                {
                    try { await Expire(id, stoppingToken); }
                    catch (Exception ex) { logger.LogError(ex, "Failed to expire order {OrderId}", id); }
                }
            }
            catch (Exception ex) { logger.LogError(ex, "Failed to expire pending orders"); }
            try { if (!await timer.WaitForNextTickAsync(stoppingToken)) break; }
            catch (OperationCanceledException) { break; }
        }
    }

    private async Task Expire(Guid id, CancellationToken stoppingToken)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ShopDbContext>();
        var shopping = scope.ServiceProvider.GetRequiredService<ShoppingService>();
        var payments = scope.ServiceProvider.GetRequiredService<PaymentService>();
        var order = await db.Orders.SingleAsync(o => o.Id == id, stoppingToken);
        if (order.Status != "PendingPayment") return;
        try
        {
            // A payment made on Stripe in the last seconds wins over the deadline.
            if (await payments.CloseCheckout(order.Id) == CheckoutClose.Paid) return;
        }
        catch (Exception ex)
        {
            // Stripe could not be asked: try again next minute. Stripe ends the page itself at its
            // expires_at, before the order deadline, so after 30 minutes the order is closed anyway.
            logger.LogWarning(ex, "Could not close the Stripe checkout of order {OrderId}", order.Id);
            if (order.ExpiresAtUtc > DateTime.UtcNow.AddMinutes(-30)) return;
        }
        await shopping.Release(order, "Expired", "Expired");
    }
}
