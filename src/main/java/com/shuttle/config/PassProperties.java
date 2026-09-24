package com.shuttle.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Configuration for the monthly pass feature.
 * {@code app.pass.mock-paid-enabled=true} activates the dev-only mock-paid flow
 * which marks a purchased pass as ACTIVE immediately without a real payment gateway.
 */
@ConfigurationProperties(prefix = "app.pass")
public record PassProperties(boolean mockPaidEnabled) {}
