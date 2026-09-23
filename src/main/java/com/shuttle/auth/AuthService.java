package com.shuttle.auth;

import com.shuttle.auth.dto.LoginRequest;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.auth.dto.TokenResponse;
import com.shuttle.config.JwtProperties;
import com.shuttle.domain.entity.RefreshToken;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.entity.VirtualBusCard;
import com.shuttle.domain.entity.Wallet;
import com.shuttle.domain.enums.CardStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.enums.WalletStatus;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.domain.repository.VirtualBusCardRepository;
import com.shuttle.domain.repository.WalletRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.security.JwtService;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Random;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final Random RANDOM = new Random();

    private final UserRepository userRepository;
    private final StudentRepository studentRepository;
    private final WalletRepository walletRepository;
    private final VirtualBusCardRepository virtualBusCardRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProperties;
    private final AuthenticationManager authenticationManager;

    // -------------------------------------------------------------------------
    // Register
    // -------------------------------------------------------------------------

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email().toLowerCase())) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_EXISTS",
                    "An account with this email already exists.");
        }
        if (studentRepository.existsByStudentId(request.studentId())) {
            throw new ApiException(HttpStatus.CONFLICT, "STUDENT_ID_ALREADY_EXISTS",
                    "An account with this student ID already exists.");
        }

        // 1. Create User
        User user = new User();
        user.setEmail(request.email().toLowerCase());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setFullName(request.name());
        user.setPhone(request.phone());
        user.setRole(Role.STUDENT);
        user.setStatus(UserStatus.ACTIVE);
        userRepository.save(user);

        // 2. Create Student profile
        Student student = new Student();
        student.setUser(user);
        student.setStudentId(request.studentId());
        student.setFaculty(request.faculty());
        student.setEnrollmentYear(request.year());
        studentRepository.save(student);

        // 3. Create Wallet with zero balance
        Wallet wallet = new Wallet();
        wallet.setStudent(student);
        wallet.setBalance(BigDecimal.ZERO);
        wallet.setStatus(WalletStatus.ACTIVE);
        walletRepository.save(wallet);

        // 4. Create VirtualBusCard  — format: UBC-{studentId}-{random4}
        String cardId = generateCardId(request.studentId());
        VirtualBusCard card = new VirtualBusCard();
        card.setStudent(student);
        card.setCardId(cardId);
        card.setStatus(CardStatus.ACTIVE);
        card.setIssuedAt(Instant.now());
        virtualBusCardRepository.save(card);

        // 5. Issue tokens
        return buildTokenResponse(user);
    }

    // -------------------------------------------------------------------------
    // Login
    // -------------------------------------------------------------------------

    public TokenResponse login(LoginRequest request) {
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(
                            request.email().toLowerCase(), request.password()));
        } catch (BadCredentialsException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS",
                    "Email or password is incorrect.");
        } catch (DisabledException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "ACCOUNT_DISABLED",
                    "Your account is not active.");
        } catch (LockedException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "ACCOUNT_LOCKED",
                    "Your account has been suspended.");
        }

        User user = userRepository.findByEmail(request.email().toLowerCase())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED,
                        "INVALID_CREDENTIALS", "Email or password is incorrect."));

        return buildTokenResponse(user);
    }

    // -------------------------------------------------------------------------
    // Refresh
    // -------------------------------------------------------------------------

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        RefreshToken stored = jwtService.validateRefreshToken(rawRefreshToken);
        User user = stored.getUser();
        return buildTokenResponse(user);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private TokenResponse buildTokenResponse(User user) {
        String accessToken = jwtService.generateAccessToken(user);
        String refreshToken = jwtService.generateRefreshToken(user);
        return new TokenResponse(accessToken, refreshToken,
                jwtProperties.expirationMs() / 1000L);
    }

    private String generateCardId(String studentId) {
        // Collision-safe: retry until unique (practically always first try)
        String cardId;
        int attempts = 0;
        do {
            int random4 = 1000 + RANDOM.nextInt(9000);
            cardId = "UBC-" + studentId + "-" + random4;
            attempts++;
            if (attempts > 10) {
                throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                        "CARD_ID_GENERATION_FAILED", "Could not generate a unique card ID.");
            }
        } while (virtualBusCardRepository.existsByCardId(cardId));
        return cardId;
    }
}
