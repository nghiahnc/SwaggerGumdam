using System.Data;
using System.Globalization;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using GundamShop.Dal;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace GundamShop.Bll;

public record PaymentSessionDto(Guid OrderId, string Provider, string Status, string? CheckoutUrl);

/// <summary>What happened to an order's Stripe Checkout page before the order is closed.</summary>
public enum CheckoutClose { NoSession, Closed, Paid }

public class PaymentService(ShopDbContext db, IConfiguration config, IHttpClientFactory clients, IHostEnvironment env, ILogger<PaymentService> logger)
{
    // Allowance for the API's clock differing from Stripe's when choosing a page's expires_at.
    private static readonly TimeSpan ClockMargin = TimeSpan.FromMinutes(5);

    private static readonly string[] StripeEvents =
        ["checkout.session.completed", "checkout.session.async_payment_succeeded", "checkout.session.async_payment_failed", "checkout.session.expired"];

    public string Provider => config["Payments:Provider"] ?? "Mock";

    // Stripe's API address. Only changed to point local tests at a stand-in server.
    private string StripeApi => (config["Payments:Stripe:ApiBase"] is { Length: > 0 } b ? b : "https://api.stripe.com").TrimEnd('/');

    /// <param name="returnBase">Address the caller reached this API at (scheme://host), used in
    /// Development for the pages Stripe sends the customer back to when SuccessUrl/CancelUrl are not
    /// configured. Elsewhere the Host header is not trusted and both URLs must be configured.</param>
    public async Task<PaymentSessionDto> Start(Guid userId, Guid orderId, string? returnBase = null)
    {
        var order = ShopGuard.Found(await db.Orders.SingleOrDefaultAsync(o => o.Id == orderId && o.UserId == userId), "đơn hàng");
        ShopGuard.Require(order.Status == "PendingPayment", "Đơn không chờ thanh toán.", 409);
        var payment = await db.Payments.SingleAsync(p => p.OrderId == orderId);
        if (Provider == "Mock") return new(orderId, "Mock", payment.Status, null);
        ShopGuard.Require(Provider == "Stripe", "Payment provider không hợp lệ.", 503);
        // An order placed while the provider was Mock is paid through Stripe now.
        if (payment.ExternalSessionId == null && payment.Provider != "Stripe")
        {
            payment.Provider = "Stripe";
            await db.SaveChangesAsync();
        }
        if (order.TotalVnd == 0)
        {
            await Complete(orderId, true);
            return new(orderId, "Stripe", "Paid", null);
        }
        if (payment.ExternalSessionId != null) return new(orderId, "Stripe", payment.Status, payment.CheckoutUrl);
        // Stripe takes an expires_at 30 minutes to 24 hours after the page is created. It is worked out
        // from the order alone, not the clock, so every request for the order asks Stripe the same thing.
        // The dates are UTC but come back from SQL Server without a Kind; read as local time they would
        // end the Stripe page hours early on a non-UTC server. An order is due 24 hours after it is
        // placed, so its page ends ClockMargin before the order: never later than now + 24 hours.
        var placed = new DateTimeOffset(DateTime.SpecifyKind(order.CreatedAtUtc, DateTimeKind.Utc));
        var deadline = new DateTimeOffset(DateTime.SpecifyKind(order.ExpiresAtUtc, DateTimeKind.Utc));
        var latest = placed.AddHours(24) - ClockMargin;
        var expiresAt = deadline < latest ? deadline : latest;
        ShopGuard.Require(expiresAt > DateTimeOffset.UtcNow.AddMinutes(30) + ClockMargin, "Đơn sắp hết hạn, hãy tạo đơn mới.", 409);
        var key = StripeKey();
        var (successUrl, cancelUrl) = ReturnUrls(env.IsDevelopment() ? returnBase : null);
        var form = new Dictionary<string, string>
        {
            ["mode"] = "payment", ["client_reference_id"] = order.Id.ToString(),
            ["success_url"] = successUrl, ["cancel_url"] = cancelUrl,
            ["line_items[0][price_data][currency]"] = "vnd",
            ["line_items[0][price_data][unit_amount]"] = order.TotalVnd.ToString(CultureInfo.InvariantCulture),
            ["line_items[0][price_data][product_data][name]"] = $"Gundam Shop order {order.Id}",
            ["line_items[0][quantity]"] = "1",
            ["metadata[orderId]"] = order.Id.ToString(),
            ["expires_at"] = expiresAt.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)
        };
        // A retry sends the same parameters and gets the same page back. A changed request (in
        // Development, another address the app used) needs its own key, or Stripe rejects it for 24 hours.
        var idempotencyKey = $"gundam-order-{order.Id}-{FormHash(form)}";
        var (ok, status, body) = await SendStripe(HttpMethod.Post, "/v1/checkout/sessions", key, form, idempotencyKey);
        // The app asked twice at once: Stripe refuses the key while the first request runs, then
        // returns that request's page for it.
        for (var wait = 500; !ok && StripeErrorCode(body) == "idempotency_key_in_use" && wait <= 2000; wait *= 2)
        {
            await Task.Delay(wait);
            (ok, status, body) = await SendStripe(HttpMethod.Post, "/v1/checkout/sessions", key, form, idempotencyKey);
        }
        // Stripe would replay a failure of its own for this key on every retry, so the order could never
        // be paid: try once with a new key. A page the failed request may have made is never handed out.
        if (!ok && status >= 500)
            (ok, status, body) = await SendStripe(HttpMethod.Post, "/v1/checkout/sessions", key, form, $"{idempotencyKey}-{Guid.NewGuid():N}");
        if (!ok)
        {
            var code = StripeErrorCode(body);
            ShopGuard.Require(code != "idempotency_key_in_use", "Trang thanh toán của đơn đang được tạo, hãy thử lại sau vài giây.", 409);
            ShopGuard.Require(code != "amount_too_small",
                "Số tiền đơn quá nhỏ để thanh toán qua Stripe. Hãy hủy đơn rồi đặt lại với tổng tiền lớn hơn.", 409);
            ShopGuard.Require(code != "amount_too_large",
                "Số tiền đơn vượt mức Stripe cho phép. Hãy hủy đơn rồi chia thành nhiều đơn nhỏ hơn.", 409);
            ShopGuard.Require(false, "Stripe từ chối tạo Checkout Session.", 502);
        }
        using var doc = JsonDocument.Parse(body);
        var sessionId = doc.RootElement.GetProperty("id").GetString();
        var url = doc.RootElement.GetProperty("url").GetString();
        ShopGuard.Require(!string.IsNullOrEmpty(sessionId) && !string.IsNullOrEmpty(url), "Stripe không trả session hợp lệ.", 502);
        // Only the first page saved for the order is handed out, also when two requests got here.
        var saved = await db.Payments.Where(p => p.OrderId == orderId && p.ExternalSessionId == null)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.ExternalSessionId, sessionId).SetProperty(p => p.CheckoutUrl, url));
        var stored = await db.Payments.AsNoTracking().SingleAsync(p => p.OrderId == orderId);
        var mine = saved == 1 || stored.ExternalSessionId == sessionId;
        // The order may have been cancelled while Stripe was creating the page.
        await db.Entry(order).ReloadAsync();
        var closed = order.Status != "PendingPayment";
        if (!mine || closed) await ExpireQuietly(sessionId!, key);
        ShopGuard.Require(!closed, "Đơn không chờ thanh toán.", 409);
        return new(orderId, "Stripe", stored.Status, stored.CheckoutUrl);
    }

    // Best effort: nobody was given this page's address, and Stripe ends it at its expires_at anyway.
    private async Task ExpireQuietly(string sessionId, string key)
    {
        try { await SendStripe(HttpMethod.Post, $"/v1/checkout/sessions/{Uri.EscapeDataString(sessionId)}/expire", key); }
        catch (ShopException) { }
    }

    /// <summary>
    /// Closes the order's Stripe Checkout page before the order is cancelled or expired, so it can no
    /// longer take money for a closed order. When Stripe reports the page was already paid, the order
    /// is marked paid instead and <see cref="CheckoutClose.Paid"/> is returned.
    /// </summary>
    public async Task<CheckoutClose> CloseCheckout(Guid orderId)
    {
        // Not tracked, so a second call in the same request sees a page that Start saved meanwhile.
        var payment = await db.Payments.AsNoTracking().SingleAsync(p => p.OrderId == orderId);
        if (Provider != "Stripe" || payment.Provider != "Stripe" || payment.ExternalSessionId == null) return CheckoutClose.NoSession;
        var key = StripeKey();
        var path = $"/v1/checkout/sessions/{Uri.EscapeDataString(payment.ExternalSessionId)}";
        var (expired, _, _) = await SendStripe(HttpMethod.Post, $"{path}/expire", key);
        if (expired) return CheckoutClose.Closed;
        // Stripe refuses to expire a page that is no longer open: find out how it ended.
        var (ok, _, body) = await SendStripe(HttpMethod.Get, path, key);
        // A page this Stripe account does not know (the key was changed) cannot take money for it.
        if (!ok && StripeErrorCode(body) == "resource_missing") return CheckoutClose.Closed;
        ShopGuard.Require(ok, "Không kiểm tra được phiên Stripe, hãy thử lại sau.", 502);
        using var doc = JsonDocument.Parse(body);
        var status = doc.RootElement.TryGetProperty("status", out var s) ? s.GetString() : null;
        var paid = doc.RootElement.TryGetProperty("payment_status", out var p) && p.GetString() == "paid";
        if (status == "expired") return CheckoutClose.Closed;
        if (status == "complete" && paid)
        {
            await Complete(orderId, true);
            return CheckoutClose.Paid;
        }
        ShopGuard.Require(status != "complete", "Stripe đang xử lý thanh toán của đơn này, hãy thử lại sau.", 409);
        ShopGuard.Require(false, "Không đóng được phiên Stripe, hãy thử lại sau.", 502);
        return CheckoutClose.Closed;
    }

    private string StripeKey()
    {
        var key = config["Payments:Stripe:SecretKey"];
        var testKey = key?.StartsWith("sk_test_", StringComparison.Ordinal) == true;
        var liveKey = !env.IsDevelopment() && config.GetValue<bool>("Payments:Stripe:AllowLive") && key?.StartsWith("sk_live_", StringComparison.Ordinal) == true;
        ShopGuard.Require(testKey || liveKey, "Cần Stripe secret key hợp lệ; live key chỉ được bật trong Production bằng Payments:Stripe:AllowLive.", 503);
        return key!;
    }

    /// <summary>
    /// Configured return pages, or the API's own /payment/success and /payment/cancel pages at the
    /// address the app used, which the customer's device can reach (10.0.2.2 on the Android emulator).
    /// </summary>
    private (string Success, string Cancel) ReturnUrls(string? returnBase)
    {
        var success = config["Payments:Stripe:SuccessUrl"];
        var cancel = config["Payments:Stripe:CancelUrl"];
        if (!Uri.TryCreate(success, UriKind.Absolute, out _) && returnBase != null)
            success = $"{returnBase}/payment/success?session_id={{CHECKOUT_SESSION_ID}}";
        if (!Uri.TryCreate(cancel, UriKind.Absolute, out _) && returnBase != null)
            cancel = $"{returnBase}/payment/cancel";
        ShopGuard.Require(Uri.TryCreate(success, UriKind.Absolute, out _) && Uri.TryCreate(cancel, UriKind.Absolute, out _), "Cần cấu hình Stripe SuccessUrl và CancelUrl.", 503);
        return (success!, cancel!);
    }

    private async Task<(bool Ok, int Status, string Body)> SendStripe(HttpMethod method, string path, string key, Dictionary<string, string>? form = null, string? idempotencyKey = null)
    {
        using var request = new HttpRequestMessage(method, StripeApi + path);
        if (form != null) request.Content = new FormUrlEncodedContent(form);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
        if (idempotencyKey != null) request.Headers.Add("Idempotency-Key", idempotencyKey);
        try
        {
            using var response = await clients.CreateClient("stripe").SendAsync(request);
            var body = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
                logger.LogWarning("Stripe {Method} {Path} returned {Status}: {Error}", method, path, (int)response.StatusCode, StripeError(body));
            return (response.IsSuccessStatusCode, (int)response.StatusCode, body);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            logger.LogWarning(ex, "Stripe {Method} {Path} could not be reached", method, path);
            throw new ShopException(502, "Không kết nối được Stripe, hãy thử lại sau.");
        }
    }

    private static string? StripeErrorCode(string body) => StripeErrorField(body, "code");

    private static string StripeError(string body) => $"{StripeErrorField(body, "code")} {StripeErrorField(body, "message")}".Trim();

    private static string? StripeErrorField(string body, string name)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            return doc.RootElement.TryGetProperty("error", out var e) && e.TryGetProperty(name, out var c) ? c.GetString() : null;
        }
        catch (JsonException) { return null; }
    }

    private static string FormHash(Dictionary<string, string> form)
    {
        var text = string.Join('\n', form.OrderBy(x => x.Key, StringComparer.Ordinal).Select(x => $"{x.Key}={x.Value}"));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)))[..16].ToLowerInvariant();
    }

    public async Task CompleteMock(Guid userId, Guid orderId, bool succeeded)
    {
        ShopGuard.Require(Provider == "Mock", "Mock payment đang tắt.", 404);
        ShopGuard.Require(await db.Orders.AnyAsync(x => x.Id == orderId && x.UserId == userId), "Không tìm thấy đơn hàng.", 404);
        await Complete(orderId, succeeded);
    }

    public async Task<bool> HandleStripeWebhook(string payload, string signature)
    {
        ShopGuard.Require(Provider == "Stripe", "Stripe đang tắt.", 404);
        var secret = config["Payments:Stripe:WebhookSecret"];
        ShopGuard.Require(secret?.StartsWith("whsec_", StringComparison.Ordinal) == true, "Thiếu webhook secret.", 503);
        ShopGuard.Require(VerifySignature(payload, signature, secret!), "Chữ ký Stripe không hợp lệ.", 400);
        using var doc = JsonDocument.Parse(payload);
        var root = doc.RootElement;
        var eventId = root.GetProperty("id").GetString() ?? "";
        var type = root.GetProperty("type").GetString() ?? "";
        ShopGuard.Require(eventId.Length > 0, "Webhook thiếu event id.");
        // Other events (payment_intent.*, charge.*) are about objects that are not Checkout pages.
        if (!StripeEvents.Contains(type)) return false;
        var session = root.GetProperty("data").GetProperty("object");
        var sessionId = session.GetProperty("id").GetString();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        if (await db.PaymentWebhookEvents.AnyAsync(e => e.EventId == eventId)) return false;
        var payment = await db.Payments.SingleOrDefaultAsync(p => p.ExternalSessionId == sessionId);
        // A page whose creation was retried and never handed out ends unpaid: nothing to record.
        if (payment == null && type == "checkout.session.expired") return false;
        ShopGuard.Require(payment != null, "Stripe session chưa được ghi nhận.", 400);
        var order = ShopGuard.Found(await db.Orders.FindAsync(payment!.OrderId), "đơn hàng");
        if (type is "checkout.session.completed" or "checkout.session.async_payment_succeeded")
        {
            var paid = session.TryGetProperty("payment_status", out var status) && status.GetString() == "paid";
            if (paid) await SetPaymentResult(order, payment, true);
        }
        else if (type == "checkout.session.async_payment_failed")
            await SetPaymentResult(order, payment, false);
        // The page reached its expires_at, 5 minutes before the order deadline: the order expired unpaid. A page
        // closed early was closed by this API (cancel, expiry job), which then closes the order itself.
        else if (type == "checkout.session.expired" && ReachedExpiry(session))
            await SetPaymentResult(order, payment, false, expired: true);
        db.PaymentWebhookEvents.Add(new PaymentWebhookEvent { EventId = eventId });
        await db.SaveChangesAsync(); await tx.CommitAsync();
        return true;
    }

    private async Task Complete(Guid orderId, bool succeeded)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        // Read again inside the transaction: the caller may hold copies loaded before a webhook or an
        // admin changed the order.
        var order = ShopGuard.Found(await db.Orders.FindAsync(orderId), "đơn hàng");
        await db.Entry(order).ReloadAsync();
        var payment = await db.Payments.SingleAsync(p => p.OrderId == orderId);
        await db.Entry(payment).ReloadAsync();
        ShopGuard.Require(payment.Provider == Provider, "Provider không khớp.", 409);
        await SetPaymentResult(order, payment, succeeded);
        await db.SaveChangesAsync(); await tx.CommitAsync();
    }

    private async Task SetPaymentResult(ShopOrder order, Payment payment, bool succeeded, bool expired = false)
    {
        if (order.Status != "PendingPayment")
        {
            if (succeeded && order.Status != "Paid" && order.Status != "Shipped" && order.Status != "Delivered")
            {
                order.PaymentStatus = "RefundRequired";
                payment.Status = "RefundRequired";
            }
            return;
        }
        if (succeeded)
        {
            order.Status = "Paid"; order.PaymentStatus = "Paid"; payment.Status = "Paid";
        }
        else
        {
            order.Status = expired ? "Expired" : "PaymentFailed";
            order.PaymentStatus = payment.Status = expired ? "Expired" : "Failed";
            var items = await db.OrderItems.Where(x => x.OrderId == order.Id).ToListAsync();
            foreach (var item in items)
            {
                var variant = ShopGuard.Found(await db.Variants.FindAsync(item.VariantId), "SKU");
                variant.Stock += item.Quantity;
            }
            if (order.VoucherId is Guid voucherId)
            {
                var voucher = ShopGuard.Found(await db.Vouchers.FindAsync(voucherId), "voucher");
                voucher.UsedCount--;
            }
        }
        payment.UpdatedAtUtc = DateTime.UtcNow;
    }

    private static bool ReachedExpiry(JsonElement session) =>
        session.TryGetProperty("expires_at", out var at) && at.TryGetInt64(out var unix)
        && unix <= (DateTimeOffset.UtcNow + ClockMargin).ToUnixTimeSeconds();

    private static bool VerifySignature(string payload, string header, string secret)
    {
        var parts = header.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(x => x.Split('=', 2)).Where(x => x.Length == 2).ToList();
        var stamp = parts.FirstOrDefault(x => x[0] == "t")?.ElementAtOrDefault(1);
        if (!long.TryParse(stamp, out var unix) || Math.Abs(DateTimeOffset.UtcNow.ToUnixTimeSeconds() - unix) > 300) return false;
        var signed = Encoding.UTF8.GetBytes($"{stamp}.{payload}");
        var expected = HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), signed);
        foreach (var signature in parts.Where(x => x[0] == "v1").Select(x => x[1]))
        {
            try { if (CryptographicOperations.FixedTimeEquals(expected, Convert.FromHexString(signature))) return true; }
            catch (FormatException) { }
        }
        return false;
    }
}
