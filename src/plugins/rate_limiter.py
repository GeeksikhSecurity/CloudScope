"""Rate limiter for plugin execution.

Implements rate limiting to prevent plugin abuse.
Requirements: 3.4, 3.6, 3.9
"""

import time
from collections import deque
from threading import Lock
from typing import Optional, Dict, Any
import logging


class RateLimiter:
    """Token bucket rate limiter for plugin execution."""
    
    def __init__(self, requests_per_minute: int = 60,
                 requests_per_hour: Optional[int] = None,
                 burst: Optional[int] = None):
        """Initialize rate limiter.
        
        Args:
            requests_per_minute: Maximum requests per minute
            requests_per_hour: Maximum requests per hour (optional)
            burst: Maximum burst size (defaults to requests_per_minute)
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        
        # Rate limits
        self.requests_per_minute = requests_per_minute
        self.requests_per_hour = requests_per_hour
        
        # Token bucket for per-minute limiting
        self.bucket_size = burst or requests_per_minute
        self.tokens = float(self.bucket_size)
        self.refill_rate = requests_per_minute / 60.0  # tokens per second
        self.last_refill = time.time()
        
        # Sliding window for per-hour limiting
        self.hour_window = deque()
        
        # Thread safety
        self._lock = Lock()
    
    def allow_request(self) -> bool:
        """Check if request is allowed under rate limits.
        
        Returns:
            True if request is allowed, False otherwise
        """
        with self._lock:
            current_time = time.time()
            
            # Check hourly limit first if configured
            if self.requests_per_hour is not None:
                if not self._check_hourly_limit(current_time):
                    return False
            
            # Refill tokens
            self._refill_tokens(current_time)
            
            # Check if we have tokens available
            if self.tokens >= 1:
                self.tokens -= 1
                
                # Record request for hourly tracking
                if self.requests_per_hour is not None:
                    self.hour_window.append(current_time)
                
                return True
            
            return False
    
    def _refill_tokens(self, current_time: float) -> None:
        """Refill tokens based on elapsed time.
        
        Args:
            current_time: Current timestamp
        """
        time_passed = current_time - self.last_refill
        tokens_to_add = time_passed * self.refill_rate
        
        self.tokens = min(self.bucket_size, self.tokens + tokens_to_add)
        self.last_refill = current_time
    
    def _check_hourly_limit(self, current_time: float) -> bool:
        """Check if hourly limit is exceeded.
        
        Args:
            current_time: Current timestamp
            
        Returns:
            True if within limit, False otherwise
        """
        # Remove old entries from window
        cutoff_time = current_time - 3600  # 1 hour ago
        while self.hour_window and self.hour_window[0] < cutoff_time:
            self.hour_window.popleft()
        
        # Check if we're at the limit
        return len(self.hour_window) < self.requests_per_hour
    
    def get_wait_time(self) -> float:
        """Get time to wait before next request is allowed.
        
        Returns:
            Seconds to wait (0 if request would be allowed now)
        """
        with self._lock:
            current_time = time.time()
            
            # Check hourly limit
            if self.requests_per_hour is not None:
                if len(self.hour_window) >= self.requests_per_hour:
                    # Find when the oldest request expires
                    oldest_request = self.hour_window[0]
                    wait_time = (oldest_request + 3600) - current_time
                    if wait_time > 0:
                        return wait_time
            
            # Check token bucket
            self._refill_tokens(current_time)
            
            if self.tokens >= 1:
                return 0
            
            # Calculate time needed for 1 token
            tokens_needed = 1 - self.tokens
            time_needed = tokens_needed / self.refill_rate
            
            return time_needed
    
    def reset(self) -> None:
        """Reset rate limiter to initial state."""
        with self._lock:
            self.tokens = float(self.bucket_size)
            self.last_refill = time.time()
            self.hour_window.clear()
    
    def get_status(self) -> Dict[str, Any]:
        """Get current rate limiter status.
        
        Returns:
            Dictionary with current status
        """
        with self._lock:
            current_time = time.time()
            self._refill_tokens(current_time)
            
            # Clean up hour window
            if self.requests_per_hour is not None:
                cutoff_time = current_time - 3600
                while self.hour_window and self.hour_window[0] < cutoff_time:
                    self.hour_window.popleft()
            
            return {
                "tokens_available": int(self.tokens),
                "bucket_size": self.bucket_size,
                "requests_per_minute": self.requests_per_minute,
                "requests_per_hour": self.requests_per_hour,
                "hourly_requests_made": len(self.hour_window) if self.requests_per_hour else None,
                "wait_time_seconds": self.get_wait_time()
            }


class SlidingWindowRateLimiter:
    """Alternative rate limiter using sliding window algorithm."""
    
    def __init__(self, requests: int, window_seconds: int):
        """Initialize sliding window rate limiter.
        
        Args:
            requests: Maximum requests in window
            window_seconds: Window size in seconds
        """
        self.max_requests = requests
        self.window_seconds = window_seconds
        self.requests = deque()
        self._lock = Lock()
    
    def allow_request(self) -> bool:
        """Check if request is allowed.
        
        Returns:
            True if allowed, False otherwise
        """
        with self._lock:
            current_time = time.time()
            cutoff_time = current_time - self.window_seconds
            
            # Remove old requests
            while self.requests and self.requests[0] < cutoff_time:
                self.requests.popleft()
            
            # Check if we can add new request
            if len(self.requests) < self.max_requests:
                self.requests.append(current_time)
                return True
            
            return False
    
    def get_wait_time(self) -> float:
        """Get time to wait before next request.
        
        Returns:
            Seconds to wait
        """
        with self._lock:
            if len(self.requests) < self.max_requests:
                return 0
            
            # Time until oldest request expires
            oldest = self.requests[0]
            current_time = time.time()
            wait_time = (oldest + self.window_seconds) - current_time
            
            return max(0, wait_time)


class CompoundRateLimiter:
    """Combines multiple rate limiters with different windows."""
    
    def __init__(self, limiters: Dict[str, RateLimiter]):
        """Initialize compound rate limiter.
        
        Args:
            limiters: Dictionary of named rate limiters
        """
        self.limiters = limiters
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def allow_request(self) -> bool:
        """Check if request is allowed by all limiters.
        
        Returns:
            True if all limiters allow, False otherwise
        """
        for name, limiter in self.limiters.items():
            if not limiter.allow_request():
                self.logger.debug(f"Request blocked by {name} limiter")
                return False
        return True
    
    def get_wait_time(self) -> float:
        """Get maximum wait time across all limiters.
        
        Returns:
            Maximum seconds to wait
        """
        max_wait = 0
        for limiter in self.limiters.values():
            wait_time = limiter.get_wait_time()
            max_wait = max(max_wait, wait_time)
        return max_wait
    
    def get_status(self) -> Dict[str, Any]:
        """Get status of all limiters.
        
        Returns:
            Dictionary with status of each limiter
        """
        return {
            name: limiter.get_status()
            for name, limiter in self.limiters.items()
        }
