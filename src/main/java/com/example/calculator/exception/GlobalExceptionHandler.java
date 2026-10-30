package com.example.calculator.exception;

import com.example.calculator.dto.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.time.Instant;

/**
 * Turns every client error into HTTP 400 + ApiError JSON.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(DivideByZeroException.class)
    public ResponseEntity<ApiError> handleDivideByZero(DivideByZeroException ex, HttpServletRequest req) {
        return badRequest(ex.getMessage(), req);
    }

    // e.g. /api/v1/add?a=2 (no b)
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ApiError> handleMissingParam(MissingServletRequestParameterException ex,
                                                       HttpServletRequest req) {
        return badRequest("Missing required parameter: " + ex.getParameterName(), req);
    }

    // e.g. /api/v1/add?a=foo&b=3
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiError> handleTypeMismatch(MethodArgumentTypeMismatchException ex,
                                                       HttpServletRequest req) {
        return badRequest("Invalid value for parameter '" + ex.getName() + "': must be a number", req);
    }

    private ResponseEntity<ApiError> badRequest(String message, HttpServletRequest req) {
        HttpStatus status = HttpStatus.BAD_REQUEST;
        ApiError body = new ApiError(
                Instant.now(),
                status.value(),
                status.getReasonPhrase(),
                message,
                req.getRequestURI());
        return ResponseEntity.status(status).body(body);
    }
}
