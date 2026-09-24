package com.shuttle.admin.settings;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/settings")
@RequiredArgsConstructor
@Tag(name = "Admin – Settings", description = "System settings management")
@SecurityRequirement(name = "bearerAuth")
public class SettingsAdminController {

    private final SystemSettingsService settingsService;

    @GetMapping
    @Operation(summary = "List all system settings (raw key-value pairs)")
    public List<SettingResponse> getAllSettings() {
        return settingsService.getAllSettings();
    }

    @PutMapping
    @Operation(summary = "Upsert a single setting by key")
    public SettingResponse upsertSetting(@Valid @RequestBody UpsertSettingRequest request) {
        return settingsService.upsertSetting(request);
    }

    @GetMapping("/config")
    @Operation(summary = "Get typed system configuration (GPS radius, GPS toggle)")
    public SystemConfigResponse getConfig() {
        return settingsService.getSystemConfig();
    }

    @PostMapping("/config")
    @Operation(summary = "Update typed system configuration")
    public SystemConfigResponse updateConfig(@Valid @RequestBody SystemConfigRequest request) {
        return settingsService.updateSystemConfig(request);
    }
}
