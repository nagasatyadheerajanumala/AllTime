# Backend Health Goals Database Table Fix

## Issue
The backend is returning a 500 error because the `user_health_goals` database table does not exist.

**Error Message:**
```
ERROR: relation "user_health_goals" does not exist
```

## Required Database Migration

The backend needs to create the `user_health_goals` table. Here's the SQL schema:

```sql
CREATE TABLE IF NOT EXISTS user_health_goals (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sleep_hours_target DOUBLE PRECISION,
    active_energy_target DOUBLE PRECISION,
    active_minutes_target INTEGER,
    resting_hr_target DOUBLE PRECISION,
    hrv_target DOUBLE PRECISION,
    steps_target INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_health_goals_user_id ON user_health_goals(user_id);
```

## JPA Entity (Java/Spring Boot)

If using JPA, the entity should look like:

```java
@Entity
@Table(name = "user_health_goals")
public class UserHealthGoals {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;
    
    @Column(name = "sleep_hours_target")
    private Double sleepHoursTarget;
    
    @Column(name = "active_energy_target")
    private Double activeEnergyTarget;
    
    @Column(name = "active_minutes_target")
    private Integer activeMinutesTarget;
    
    @Column(name = "resting_hr_target")
    private Double restingHrTarget;
    
    @Column(name = "hrv_target")
    private Double hrvTarget;
    
    @Column(name = "steps_target")
    private Integer stepsTarget;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    @CreationTimestamp
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at", nullable = false)
    @UpdateTimestamp
    private LocalDateTime updatedAt;
    
    // Getters and setters...
}
```

## API Endpoints Expected

The frontend expects these endpoints:

### GET `/api/v1/health/goals`
- Returns: `UserHealthGoals` object
- Returns 404 if user has no goals yet
- Returns 200 with goals if they exist

### POST `/api/v1/health/goals`
- Request Body: `SaveGoalsRequest` (snake_case)
  ```json
  {
    "sleep_hours": 8.0,
    "steps": 10000,
    "active_minutes": 60,
    "active_energy_burned": 600.0,
    "resting_heart_rate": 60.0,
    "hrv": 50.0
  }
  ```
- Response: `SaveGoalsResponse`
  ```json
  {
    "goals": {
      "sleep_hours": 8.0,
      "steps": 10000,
      "active_minutes": 60,
      "active_energy_burned": 600.0,
      "resting_heart_rate": 60.0,
      "hrv": 50.0,
      "updated_at": "2025-01-XX..."
    },
    "message": "Goals saved successfully"
  }
  ```

## Frontend Workaround

The frontend now:
1. **Saves goals locally** even if backend fails
2. **Shows success message** when saved locally
3. **Uses cached goals** if backend is unavailable
4. **Still notifies views** to regenerate suggestions based on local goals

This ensures the app works even while the backend table is being created.

## Next Steps

1. Run the database migration to create the table
2. Deploy the migration
3. Test the endpoints
4. The frontend will automatically start syncing with the backend once it's available

