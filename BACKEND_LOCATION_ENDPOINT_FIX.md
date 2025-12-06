# Backend Fix: Location Endpoint Returning 500 Error

## 🚨 **Current Issue**

iOS app is correctly sending New Brunswick, NJ location, but backend returns:
```
POST /api/v1/location → 500 Internal Server Error
```

---

## 📊 **What iOS is Sending**

```json
POST https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/location
Headers:
  Authorization: Bearer eyJhbGciOiJIUzUxMiJ9...
  Content-Type: application/json

Body:
{
  "latitude": 40.48723806136594,
  "longitude": -74.43972207921836,
  "address": "161, George St, New Brunswick, NJ",
  "city": "New Brunswick",
  "country": "United States"
}
```

---

## ✅ **Backend Implementation Needed**

### **File: Create or Update Location Controller**

```java
package com.alltime.controller;

import com.alltime.dto.LocationUpdateRequest;
import com.alltime.service.LocationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/location")
@RequiredArgsConstructor
@Slf4j
public class LocationController {

    private final LocationService locationService;

    @PostMapping
    public ResponseEntity<Map<String, String>> updateLocation(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody LocationUpdateRequest request
    ) {
        try {
            log.info("Received location update for user: {}", userDetails.getUsername());
            log.info("Location: {}, {} - {}, {}", 
                request.getLatitude(), 
                request.getLongitude(),
                request.getCity(),
                request.getCountry()
            );

            locationService.updateUserLocation(
                userDetails.getUsername(),
                request.getLatitude(),
                request.getLongitude(),
                request.getAddress(),
                request.getCity(),
                request.getCountry()
            );

            log.info("Location updated successfully");
            return ResponseEntity.ok(Map.of(
                "message", "Location updated successfully",
                "city", request.getCity() != null ? request.getCity() : "Unknown"
            ));

        } catch (Exception e) {
            log.error("Failed to update location", e);
            return ResponseEntity
                .status(500)
                .body(Map.of("error", "Failed to update location", "message", e.getMessage()));
        }
    }
}
```

### **File: Create Location DTO**

```java
package com.alltime.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class LocationUpdateRequest {
    
    @JsonProperty("latitude")
    private Double latitude;
    
    @JsonProperty("longitude")
    private Double longitude;
    
    @JsonProperty("address")
    private String address;
    
    @JsonProperty("city")
    private String city;
    
    @JsonProperty("country")
    private String country;
}
```

### **File: Create Location Service**

```java
package com.alltime.service;

import com.alltime.entity.User;
import com.alltime.entity.UserLocation;
import com.alltime.repository.UserLocationRepository;
import com.alltime.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class LocationService {

    private final UserLocationRepository locationRepository;
    private final UserRepository userRepository;

    @Transactional
    public void updateUserLocation(String username, 
                                   Double latitude, 
                                   Double longitude,
                                   String address, 
                                   String city, 
                                   String country) {
        
        // Find user by Apple sub or email
        User user = userRepository.findByAppleSubOrEmail(username)
            .orElseThrow(() -> new RuntimeException("User not found: " + username));

        // Check if user already has a location
        UserLocation location = locationRepository.findByUserId(user.getId())
            .orElse(new UserLocation());

        // Update location data
        location.setUserId(user.getId());
        location.setLatitude(latitude);
        location.setLongitude(longitude);
        location.setAddress(address);
        location.setCity(city);
        location.setCountry(country);
        location.setUpdatedAt(LocalDateTime.now());
        
        if (location.getId() == null) {
            location.setCreatedAt(LocalDateTime.now());
        }

        locationRepository.save(location);
        
        log.info("Saved location for user {}: {}, {}", user.getId(), city, country);
    }
}
```

### **File: Create Location Entity**

```java
package com.alltime.entity;

import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;

@Entity
@Table(name = "user_locations")
@Data
public class UserLocation {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "user_id", nullable = false, unique = true)
    private Long userId;
    
    @Column(nullable = false)
    private Double latitude;
    
    @Column(nullable = false)
    private Double longitude;
    
    private String address;
    
    private String city;
    
    private String country;
    
    @Column(name = "accuracy_meters")
    private Double accuracyMeters;
    
    @Column(name = "location_type")
    private String locationType;
    
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
```

### **File: Create Location Repository**

```java
package com.alltime.repository;

import com.alltime.entity.UserLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserLocationRepository extends JpaRepository<UserLocation, Long> {
    
    Optional<UserLocation> findByUserId(Long userId);
    
    void deleteByUserId(Long userId);
}
```

---

## 🧪 **Testing**

### Test the Endpoint with curl:

```bash
# Replace YOUR_JWT_TOKEN with actual token
curl -X POST \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/location" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 40.48723806136594,
    "longitude": -74.43972207921836,
    "address": "161, George St, New Brunswick, NJ",
    "city": "New Brunswick",
    "country": "United States"
  }'
```

**Expected**: `200 OK`  
**Currently**: `500 Internal Server Error`

---

## ✅ **After Backend Fix**

Once `/api/v1/location` returns 200 OK, the flow will be:

```
iOS sends NJ location → Backend saves (200 OK)
    ↓
iOS fetches lunch recommendations
    ↓
Backend queries restaurants near (40.487, -74.440)
    ↓
Returns NJ restaurants (not SF!)
    ↓
iOS displays: "Tony's Pizza (0.3km, ⭐4.8)" ← New Brunswick restaurant!
```

---

## 📝 **Quick Fix Checklist for Backend**

- [ ] Create `LocationController.java`
- [ ] Create `LocationUpdateRequest.java` DTO
- [ ] Create `LocationService.java`
- [ ] Create `UserLocation.java` entity
- [ ] Create `UserLocationRepository.java`
- [ ] Test with curl (should return 200)
- [ ] Verify location saved in database
- [ ] Update lunch/walk endpoints to USE this location

---

**Once the backend accepts the location, you'll immediately see New Brunswick, NJ restaurants!** 🎉

**iOS Status**: ✅ PERFECT  
**Backend Status**: ❌ NEEDS FIX  
**SQL Table**: ✅ CREATED  
**Endpoint Code**: ❌ NEEDED

