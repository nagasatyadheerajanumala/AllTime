# Today Tab - Current UI/UX Documentation

**Last Updated:** January 2026
**Purpose:** Reference document for UI/UX redesign

---

## Overview

The Today tab is the primary landing screen of AllTime. It serves as a **decision surface** for users to understand their day and week at a glance and take action. The core philosophy is that Clara (the AI assistant) should be **opinionated, not observational** - the screen should tell users what to do, not just show them data.

---

## Navigation Structure

### Header (Navigation Bar)
| Element | Position | Description |
|---------|----------|-------------|
| **"Today"** | Title | Large navigation title |
| **Customize Layout Button** | Leading | Grid icon to enter tile reorder mode |
| **Notification Bell** | Trailing | Shows unread count badge (red dot) |
| **Refresh Button** | Trailing | Spinning animation while loading |

---

## Screen Layout (Top to Bottom)

### 1. HERO SUMMARY CARD (Fixed Position - Always First)

**Purpose:** The heart of Clara's decision engine. NOT a status page - a decision surface.

**Visual Treatment:**
- Dark gradient background (#1E1E2E → #151520)
- Full-width card with rounded corners (XL radius)
- Minimum height: 180pt
- Severity-based accent glow (top-right radial gradient)
- Severity-based border color

**Content Structure:**
```
┌─────────────────────────────────────────────────┐
│ [Severity Badge]                    Day X of 7  │
│                                                 │
│ Headline (Bold, Title3)                         │
│ Subheadline (Regular, opacity 75%)              │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ ⚠️ Risk Signal (if drifting)                │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ [Icon] Primary Intervention          →      │ │
│ │        Supporting detail                    │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ✨ Ask Clara what to protect today         >   │
└─────────────────────────────────────────────────┘
```

**Severity States:**
| Severity | Color | Icon | Badge Text |
|----------|-------|------|------------|
| On Track | Green (#10B981) | checkmark.circle.fill | "On Track" |
| Watch | Amber (#F59E0B) | eye.fill | "Watch" |
| Drifting | Orange (#F97316) | exclamationmark.triangle.fill | "Drifting" |
| Critical | Red (#EF4444) | exclamationmark.octagon.fill | "Critical" |

**Data Displayed:**
- Week drift score (0-100, internal)
- Day of week (e.g., "Day 2 of 7")
- Headline: Opinionated statement about week status
- Subheadline: Context about opportunity or risk
- Week projection: What happens if nothing changes
- Primary intervention: THE one recommendation to act on

**Interactions:**
- Tap card → Opens Summary Detail Sheet
- Tap intervention → Deep link navigation (calendar, health, etc.)

---

### 2. CRITICAL HEALTH ALERT BANNER (Conditional - Fixed After Hero)

**Shows when:** Health data is critical or suspect (e.g., 0.3h sleep reported)

**Visual:** Warning banner with health severity info

---

### 3. REORDERABLE TILES SECTION

Users can customize the order of these tiles via drag-and-drop in reorder mode.

#### 3A. PRIMARY RECOMMENDATION CARD
**Purpose:** THE one thing Clara recommends doing today (opinionated, not a list)

**Content:**
- Action title (e.g., "Block 90 minutes for deep work")
- Reason/detail
- Urgency indicator (now / today / this_week)
- Impact level
- Category (protect_time, reduce_load, health, catch_up)
- Icon

**Interactions:**
- Tap → Opens Primary Recommendation Action Sheet
- Collapsible (single-tile expansion - only one tile expanded at a time)

---

#### 3B. CLARA PROMPTS CARD
**Purpose:** Contextual prompts that teach users how to use Clara

**Content:**
- List of 2-4 contextual prompts based on day state
- Each prompt has: label, type, context

**Examples:**
- "What should I protect today?"
- "What's at risk this week?"
- "What can I move or drop?"

**Interactions:**
- Tap prompt → Opens Clara Prompt Sheet (starts conversation with Clara)
- Collapsible

---

#### 3C. ENERGY BUDGET CARD
**Purpose:** Time → Energy transformation (not all hours are equal)

**Content:**
- Total energy budget visualization
- Meeting energy cost
- Focus time available
- Recovery recommendations

**Interactions:**
- Collapsible

---

#### 3D. DECISION MOMENTS CARD
**Purpose:** Key decision points in the day

**Content:**
- Time-based decision moments
- Action recommendations

---

#### 3E. SIMILAR WEEK SECTION
**Purpose:** Historical context - "You've had weeks like this before"

**Content:**
- Comparison to similar past weeks
- What worked / what didn't

---

#### 3F. MEETING SPOTS SECTION
**Purpose:** Optimal time slots for scheduling meetings

**Content:**
- Recommended meeting times based on energy patterns

---

#### 3G. ACTIONS ROW (Suggestions + Tasks)
**Purpose:** Quick access to suggestions and to-do list

**Content:**
- Suggestions count with preview
- Tasks count with pending/overdue breakdown

**Interactions:**
- Tap Suggestions → Opens Suggestions Detail Sheet
- Tap Tasks → Opens ToDo Detail Sheet
- Collapsible

---

#### 3H. UP NEXT SECTION
**Purpose:** Immediate upcoming events

**Content:**
- Next 2-3 events with time, title, duration

---

### 4. SCHEDULE SECTION (Fixed Position - Near Bottom)

**Shows when:** User has events today

**Visual:** Collapsible card with event list

**Content:**
```
┌─────────────────────────────────────────────────┐
│ Schedule                          X events    > │
├─────────────────────────────────────────────────┤
│ [Color] 9:00 AM  Meeting Title                  │
│         1h · Conference Room                    │
│                                                 │
│ [Color] 10:30 AM  Event Title         ● NOW    │
│         30m · Zoom                              │
│                                                 │
│ [Dimmed] Past events at 60% opacity             │
└─────────────────────────────────────────────────┘
```

**Event Row Content:**
- Color bar (calendar color)
- Time (h:mm a format)
- Title
- Duration
- Location (if available)
- "NOW" badge for current event
- Past events dimmed

**Interactions:**
- Tap event → Opens Event Detail Sheet
- Collapsible (part of single-tile expansion system)

---

### 5. HEALTH ACCESS CARD (Conditional - Fixed at Bottom)

**Shows when:** HealthKit authorization not granted

**Purpose:** Prompt user to grant health data access

---

## Floating Action Button (FAB)

**Position:** Bottom-right, above tab bar (160pt from bottom)

**Visual:**
- 56pt circular button
- Blue gradient (primary → primaryDark)
- Shadow with blur

**States:**
- Closed: Plus icon, blue gradient
- Open: X icon (rotated 90°), gray gradient, dimmed background overlay

**Expanded Menu Options (bottom to top):**
| Option | Icon | Color | Condition |
|--------|------|-------|-----------|
| Quick Pick | sparkles | Pink (#EC4899) | Weekend/Holiday only |
| Plan My Day | wand.and.stars | Violet | Always |
| Quick Book | calendar.badge.clock | Cyan (#06B6D4) | Always |
| Add Reminder | bell.fill | Amber | Always |
| Add Task | checkmark.circle.fill | Emerald | Always |
| Add Event | calendar.badge.plus | Blue | Always |

**Menu Item Visual:**
```
┌────────────────┐  ┌────┐
│  Label Text    │  │ ⊕  │
└────────────────┘  └────┘
   Capsule bg      44pt circle
```

---

## Interaction Patterns

### Progressive Disclosure
- **Single-tile expansion:** Only ONE tile can be expanded at a time
- Tapping a collapsed tile expands it and collapses any other
- Reduces cognitive overload

### Tile Reordering
- Activated via grid icon in nav bar
- Shows "Reorder Mode Header" when active
- Tiles can be dragged to reorder
- Order persists across sessions

### Pull-to-Refresh
- Refreshes all data sources:
  - Fresh HealthKit metrics
  - Calendar events
  - Daily briefing
  - Today overview
  - Week drift status

### Skeleton Loading
- All cards show skeleton placeholders while loading
- Shimmer animation on skeleton elements

---

## Sheet Presentations

| Trigger | Sheet |
|---------|-------|
| Tap Hero Card | TodaySummaryDetailView |
| Tap Suggestions | SuggestionsDetailView |
| Tap Tasks | ToDoDetailView |
| Tap "Plan My Day" | PlanMyDayView |
| Tap Notification Bell | NotificationHistoryView |
| Tap Event | LocalEventDetailSheet |
| Tap Clara Prompt | ClaraPromptSheet |
| Tap Primary Recommendation | PrimaryRecommendationActionSheet |
| Tap "Add Event" | AddEventView |
| Tap "Add Task" | AddTaskSheet |
| Tap "Add Reminder" | AddReminderSheet |
| Tap "Quick Pick" | WeekendQuickPickView |
| Tap "Quick Book" | QuickBookView |

---

## Data Sources

| Data | Source | Refresh Strategy |
|------|--------|------------------|
| Calendar Events | CalendarViewModel | On appear + pull-to-refresh |
| Daily Briefing | TodayBriefingViewModel (API) | Cached + background refresh |
| Today Overview | TodayOverviewViewModel (API) | Cached + background refresh |
| Week Drift | APIService.getWeekDriftStatus() | On appear + pull-to-refresh |
| Health Metrics | HealthMetricsService (HealthKit) | Fresh fetch on appear |
| Notifications | NotificationHistoryService | Observable |

---

## Design Tokens Used

**Colors:**
- `DesignSystem.Colors.background` - Main background
- `DesignSystem.Colors.cardBackground` - Card backgrounds
- `DesignSystem.Colors.primaryText` - Main text
- `DesignSystem.Colors.secondaryText` - Subheadings
- `DesignSystem.Colors.tertiaryText` - Hints, captions
- `DesignSystem.Colors.primary` - Action color (blue)
- `DesignSystem.Colors.amber` - Warnings
- `DesignSystem.Colors.emerald` - Success/Tasks
- `DesignSystem.Colors.violet` - Clara/AI features

**Spacing:**
- `DesignSystem.Spacing.xs` - 4pt
- `DesignSystem.Spacing.sm` - 8pt
- `DesignSystem.Spacing.md` - 16pt
- `DesignSystem.Spacing.lg` - 24pt
- `DesignSystem.Spacing.xl` - 32pt

**Corner Radius:**
- `DesignSystem.CornerRadius.lg` - Standard cards
- `DesignSystem.CornerRadius.xl` - Hero card

---

## Known Pain Points (For Redesign Consideration)

1. **Information Density:** Too many tiles, overwhelming on first load
2. **Tile Reordering:** Feature exists but not discoverable
3. **Priority Hierarchy:** Not clear what user should focus on first
4. **Clara Integration:** Prompts feel disconnected from main content
5. **Schedule Section:** Buried at bottom despite being important
6. **FAB Menu:** 6 options may be too many
7. **Empty States:** Not designed for days with no events or data
8. **Weekend Mode:** Different needs on weekends not fully addressed

---

## Key Philosophy (From Code Comments)

> "Clara exists to prevent bad weeks before they happen."
> "Time is not neutral. A meeting-free day can still be draining."
> "Retrospective insight is table stakes. Clara forecasts."
> "Clara is opinionated. It makes recommendations, not suggestions."
> "The unit of value is the week."

The Hero Card is described as:
> "NOT a status page. It is a decision surface."

---

## Appendix: Complete Tile Type Enumeration

```
Fixed (Top):
- heroSummary
- criticalHealthAlert

Reorderable (Middle):
- primaryRecommendation
- claraPrompts
- energyBudget
- decisionMoments
- similarWeek
- meetingSpots
- actionsRow
- upNext

Fixed (Bottom):
- schedule
- healthAccess
```
