package com.shuttle.wallet;

import com.shuttle.wallet.dto.TopUpRequest;
import com.shuttle.wallet.dto.TopUpResponse;
import com.shuttle.wallet.dto.TransactionItem;
import com.shuttle.wallet.dto.WalletResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/wallet")
@RequiredArgsConstructor
@Tag(name = "Wallet", description = "Student wallet management")
@SecurityRequirement(name = "bearerAuth")
public class WalletController {

    private final WalletService walletService;

    @GetMapping
    @Operation(summary = "Get wallet balance and status")
    public WalletResponse getWallet(Authentication auth) {
        return walletService.getWallet(auth);
    }

    @GetMapping("/transactions")
    @Operation(summary = "Get wallet transaction history")
    public List<TransactionItem> getTransactions(Authentication auth) {
        return walletService.getTransactions(auth);
    }

    @PostMapping("/top-up")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Initiate a wallet top-up — returns a gateway checkout URL")
    public TopUpResponse topUp(@Valid @RequestBody TopUpRequest request,
                                Authentication auth) {
        return walletService.initiateTopUp(request, auth);
    }
}
