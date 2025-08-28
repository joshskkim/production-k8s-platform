package com.trading.payments.exception;

import com.trading.payments.dto.PaymentResponse;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.MethodArgumentNotValidException;

import java.util.stream.Collectors;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

@ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<PaymentResponse> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(err -> err.getDefaultMessage())
                .collect(Collectors.joining("; "));

        return ResponseEntity.badRequest().body(
                PaymentResponse.builder()
                        .status("DECLINED")
                        .message(message) // or just "Invalid amount" if you want
                        .build()
        );
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<PaymentResponse> handleOtherExceptions(Exception ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(
                PaymentResponse.builder()
                        .status("FAILED")
                        .message("Internal processing error")
                        .build()
        );
    }
}
