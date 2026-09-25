package com.shuttle.config;

import java.math.BigDecimal;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.notification")
public record NotificationProperties(
        BigDecimal lowBalanceThreshold,
        String firebaseCredentials,
        String firebaseConfigPath
) {
    public NotificationProperties {
        if (lowBalanceThreshold == null) {
            lowBalanceThreshold = new BigDecimal("200.00");
        }
    }
}
