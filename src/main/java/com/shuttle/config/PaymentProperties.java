package com.shuttle.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.payment")
public record PaymentProperties(
        String gateway,    // "mock" | "payhere"
        String baseUrl     // e.g. "http://localhost:8080" — used to build webhook URLs
) {}
