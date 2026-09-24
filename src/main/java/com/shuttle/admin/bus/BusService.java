package com.shuttle.admin.bus;

import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.exception.ApiException;
import jakarta.persistence.EntityNotFoundException;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class BusService {

    private final BusRepository busRepository;

    @Transactional(readOnly = true)
    public List<BusResponse> listAll() {
        return busRepository.findAll().stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public BusResponse getById(Long id) {
        return toResponse(load(id));
    }

    @Transactional
    public BusResponse create(BusRequest req) {
        if (busRepository.findByBusNumber(req.busNumber()).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "BUS_NUMBER_EXISTS",
                    "Bus number '" + req.busNumber() + "' is already registered.");
        }
        if (busRepository.findByPlateNumber(req.plateNumber()).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "PLATE_NUMBER_EXISTS",
                    "Plate number '" + req.plateNumber() + "' is already registered.");
        }
        Bus bus = new Bus();
        apply(bus, req);
        return toResponse(busRepository.save(bus));
    }

    @Transactional
    public BusResponse update(Long id, BusRequest req) {
        Bus bus = load(id);
        if (busRepository.existsByBusNumberAndIdNot(req.busNumber(), id)) {
            throw new ApiException(HttpStatus.CONFLICT, "BUS_NUMBER_EXISTS",
                    "Bus number '" + req.busNumber() + "' is already used by another bus.");
        }
        if (busRepository.existsByPlateNumberAndIdNot(req.plateNumber(), id)) {
            throw new ApiException(HttpStatus.CONFLICT, "PLATE_NUMBER_EXISTS",
                    "Plate number '" + req.plateNumber() + "' is already used by another bus.");
        }
        apply(bus, req);
        return toResponse(busRepository.save(bus));
    }

    @Transactional
    public void delete(Long id) {
        busRepository.delete(load(id));
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private Bus load(Long id) {
        return busRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Bus " + id + " not found."));
    }

    private void apply(Bus bus, BusRequest req) {
        bus.setBusNumber(req.busNumber());
        bus.setPlateNumber(req.plateNumber());
        bus.setCapacity(req.capacity());
        bus.setModel(req.model());
        bus.setStatus(BusStatus.valueOf(req.status().toUpperCase()));
    }

    BusResponse toResponse(Bus bus) {
        return new BusResponse(
                bus.getId(), bus.getBusNumber(), bus.getPlateNumber(),
                bus.getCapacity(), bus.getModel(), bus.getStatus().name(),
                bus.getCreatedAt(), bus.getUpdatedAt());
    }
}
