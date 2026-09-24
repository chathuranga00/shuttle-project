package com.shuttle.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/**
 * Key-value store for runtime-configurable system settings.
 * All settings are stored as strings; the service layer handles
 * type conversion (e.g. "100" → int for GPS radius).
 */
@Getter
@Setter
@Entity
@Table(
        name = "system_settings",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_system_settings_key",
                columnNames = "setting_key")
)
public class SystemSetting extends BaseEntity {

    @Column(name = "setting_key", nullable = false, unique = true, length = 100)
    private String settingKey;

    @Column(name = "setting_value", nullable = false, length = 500)
    private String settingValue;

    @Column(length = 255)
    private String description;
}
