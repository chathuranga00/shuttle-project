package com.shuttle.config;

import com.shuttle.domain.entity.Admin;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.AdminRepository;
import com.shuttle.domain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Seeds a default ADMIN user on first startup in the {@code dev} profile only.
 * Idempotent — does nothing if the seed email already exists.
 */
@Slf4j
@Component
@Profile("dev")
@RequiredArgsConstructor
public class AdminSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final AdminRepository adminRepository;
    private final PasswordEncoder passwordEncoder;
    private final AdminProperties adminProperties;

    @Override
    @Transactional
    public void run(String... args) {
        String email = adminProperties.seedEmail();

        if (userRepository.existsByEmail(email)) {
            log.info("Admin seed skipped — user '{}' already exists.", email);
            return;
        }

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(adminProperties.seedPassword()));
        user.setFullName("System Administrator");
        user.setRole(Role.ADMIN);
        user.setStatus(UserStatus.ACTIVE);
        userRepository.save(user);

        Admin admin = new Admin();
        admin.setUser(user);
        admin.setJobTitle("System Administrator");
        adminRepository.save(admin);

        log.info("Default admin account created: {}", email);
    }
}
