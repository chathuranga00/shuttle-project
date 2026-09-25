package com.shuttle.domain.repository;

import com.shuttle.domain.entity.DeviceToken;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
    List<DeviceToken> findByUserId(Long userId);
    List<DeviceToken> findByUserIdIn(List<Long> userIds);
    Optional<DeviceToken> findByToken(String token);
    void deleteByToken(String token);
    void deleteByUserId(Long userId);
}
