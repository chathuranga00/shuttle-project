package com.shuttle.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.exception.ApiError;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Rate limits sensitive endpoints (login, register, boarding confirmation, payment operations)
 * per IP address using Bucket4j in-memory token buckets.
 */
@Component
@RequiredArgsConstructor
public class RateLimitFilter extends OncePerRequestFilter {

    public enum EndpointLimit {
        AUTH_LOGIN(10, "Too many login attempts. Please wait a minute before trying again."),
        AUTH_REGISTER(10, "Too many registration attempts. Please wait a minute before trying again."),
        BOARDING_CONFIRM(15, "Too many boarding confirmation attempts. Please wait a minute before trying again."),
        WALLET_TOPUP(10, "Too many wallet top-up requests. Please wait a minute before trying again."),
        PASS_PURCHASE(10, "Too many pass purchase requests. Please wait a minute before trying again.");

        private final int limitPerMinute;
        private final String message;

        EndpointLimit(int limitPerMinute, String message) {
            this.limitPerMinute = limitPerMinute;
            this.message = message;
        }

        public int getLimitPerMinute() {
            return limitPerMinute;
        }

        public String getMessage() {
            return message;
        }
    }

    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain) throws ServletException, IOException {

        EndpointLimit limitConfig = resolveEndpointLimit(request);
        if (limitConfig != null) {
            String ip = resolveClientIp(request);
            String bucketKey = ip + ":" + limitConfig.name();
            Bucket bucket = buckets.computeIfAbsent(bucketKey, k -> newBucket(limitConfig.getLimitPerMinute()));

            if (!bucket.tryConsume(1)) {
                ApiError error = new ApiError(
                        Instant.now(),
                        HttpStatus.TOO_MANY_REQUESTS.value(),
                        "RATE_LIMIT_EXCEEDED",
                        limitConfig.getMessage());
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                objectMapper.writeValue(response.getOutputStream(), error);
                return;
            }
        }

        filterChain.doFilter(request, response);
    }

    private EndpointLimit resolveEndpointLimit(HttpServletRequest request) {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            return null;
        }
        String uri = request.getRequestURI();
        if ("/api/auth/login".equals(uri)) return EndpointLimit.AUTH_LOGIN;
        if ("/api/auth/register".equals(uri)) return EndpointLimit.AUTH_REGISTER;
        if ("/api/boarding/confirm".equals(uri)) return EndpointLimit.BOARDING_CONFIRM;
        if ("/api/wallet/top-up".equals(uri)) return EndpointLimit.WALLET_TOPUP;
        if ("/api/monthly-pass/purchase".equals(uri)) return EndpointLimit.PASS_PURCHASE;
        return null;
    }

    private Bucket newBucket(int maxRequestsPerMinute) {
        Bandwidth limit = Bandwidth.builder()
                .capacity(maxRequestsPerMinute)
                .refillGreedy(maxRequestsPerMinute, Duration.ofMinutes(1))
                .build();
        return Bucket.builder().addLimit(limit).build();
    }

    private String resolveClientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
