package com.shuttle.pass;

import com.shuttle.pass.dto.PassListItem;
import com.shuttle.pass.dto.PassStatusResponse;
import com.shuttle.pass.dto.PurchasePassRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@RequestMapping("/api/monthly-pass")
@RequiredArgsConstructor
@Tag(name = "Monthly Pass", description = "Student monthly pass management")
@SecurityRequirement(name = "bearerAuth")
public class MonthlyPassController {

    private final MonthlyPassService passService;

    @GetMapping
    @Operation(summary = "List all passes for the authenticated student")
    public List<PassListItem> listPasses(Authentication auth) {
        return passService.listPasses(auth);
    }

    @GetMapping("/status")
    @Operation(summary = "Get current pass status and next purchase price")
    public PassStatusResponse getStatus(Authentication auth) {
        return passService.getStatus(auth);
    }

    @PostMapping("/purchase")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Purchase a monthly pass (mock-paid in dev, PENDING in prod)")
    public PassStatusResponse purchase(
            @RequestBody(required = false) PurchasePassRequest request,
            Authentication auth) {
        return passService.purchase(
                request != null ? request : new PurchasePassRequest(null), auth);
    }
}
