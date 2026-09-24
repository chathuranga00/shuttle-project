package com.shuttle.admin.settings;

import com.shuttle.domain.entity.SystemSetting;
import com.shuttle.domain.repository.SystemSettingRepository;
import com.shuttle.exception.ApiException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SystemSettingsService {

    // Well-known keys
    public static final String KEY_GPS_RADIUS  = "gps.radius.meters";
    public static final String KEY_GPS_ENABLED = "gps.verification.enabled";

    private final SystemSettingRepository settingRepository;

    @Transactional(readOnly = true)
    public List<SettingResponse> getAllSettings() {
        return settingRepository.findAll().stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public SettingResponse getSetting(String key) {
        return toResponse(loadByKey(key));
    }

    @Transactional
    public SettingResponse upsertSetting(UpsertSettingRequest request) {
        SystemSetting setting = settingRepository.findBySettingKey(request.key())
                .orElseGet(SystemSetting::new);
        setting.setSettingKey(request.key());
        setting.setSettingValue(request.value());
        if (request.description() != null) {
            setting.setDescription(request.description());
        }
        return toResponse(settingRepository.save(setting));
    }

    /** Typed accessor — GPS radius in metres (default 100). */
    @Transactional(readOnly = true)
    public int getGpsRadiusMetres() {
        return settingRepository.findBySettingKey(KEY_GPS_RADIUS)
                .map(s -> Integer.parseInt(s.getSettingValue()))
                .orElse(100);
    }

    /** Typed accessor — GPS verification enabled flag (default true). */
    @Transactional(readOnly = true)
    public boolean isGpsVerificationEnabled() {
        return settingRepository.findBySettingKey(KEY_GPS_ENABLED)
                .map(s -> Boolean.parseBoolean(s.getSettingValue()))
                .orElse(true);
    }

    /** Returns current GPS / system config as a typed DTO. */
    @Transactional(readOnly = true)
    public SystemConfigResponse getSystemConfig() {
        return new SystemConfigResponse(getGpsRadiusMetres(), isGpsVerificationEnabled());
    }

    /** Update GPS settings via the typed config DTO. */
    @Transactional
    public SystemConfigResponse updateSystemConfig(SystemConfigRequest request) {
        upsert(KEY_GPS_RADIUS,  String.valueOf(request.gpsRadiusMetres()),
               "Radius in metres for GPS proximity check");
        upsert(KEY_GPS_ENABLED, String.valueOf(request.gpsVerificationEnabled()),
               "Whether GPS check is enforced during boarding");
        return getSystemConfig();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private void upsert(String key, String value, String description) {
        SystemSetting s = settingRepository.findBySettingKey(key).orElseGet(SystemSetting::new);
        s.setSettingKey(key);
        s.setSettingValue(value);
        s.setDescription(description);
        settingRepository.save(s);
    }

    private SystemSetting loadByKey(String key) {
        return settingRepository.findBySettingKey(key)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "SETTING_NOT_FOUND", "Setting '" + key + "' not found."));
    }

    private SettingResponse toResponse(SystemSetting s) {
        return new SettingResponse(s.getId(), s.getSettingKey(),
                s.getSettingValue(), s.getDescription());
    }
}
