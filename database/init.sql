-- schema.sql
-- Persian Calendar — MySQL schema (professional)
-- Assumes MySQL 8.x
-- Charset & collation for full Unicode (including emoji)
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Create database (adjust name if needed)
CREATE DATABASE IF NOT EXISTS persian_calendar
  CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
USE persian_calendar;

-- ----------------------------------------------------------------
-- Helpful functions for UUID binary storage (useful for performance)
-- (MySQL builtin UUID_TO_BIN/UUID_FROM_BIN exist in 8.x)
-- We'll store UUIDs as BINARY(16) to save space & speed.
-- Application should use UUID() or UUID_TO_BIN(UUID()) when inserting.
-- ----------------------------------------------------------------

-- ----------------------------------------------------------------
-- users: accounts
-- ----------------------------------------------------------------
CREATE TABLE users (
  id BINARY(16) NOT NULL PRIMARY KEY,            -- UUID binary(16)
  username VARCHAR(64) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,          -- store bcrypt/argon2 hash
  display_name VARCHAR(255),
  locale VARCHAR(10) DEFAULT 'fa_IR',
  timezone VARCHAR(64) DEFAULT 'Asia/Tehran',
  is_active TINYINT(1) DEFAULT 1,
  is_admin TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- calendars: multiple calendars per user
-- ----------------------------------------------------------------
CREATE TABLE calendars (
  id BINARY(16) NOT NULL PRIMARY KEY,
  owner_id BINARY(16) NULL,            -- nullable for system or shared calendars
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  color CHAR(7) DEFAULT '#4A76FF',     -- hex color
  is_default TINYINT(1) DEFAULT 0,
  is_public TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(3),
  FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_calendars_owner (owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- events: master event record (supports recurring via rrule/text)
-- ----------------------------------------------------------------
CREATE TABLE events (
  id BINARY(16) NOT NULL PRIMARY KEY,
  calendar_id BINARY(16) NOT NULL,
  creator_id BINARY(16) NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  location VARCHAR(255) NULL,
  start_dt DATETIME(3) NOT NULL,          -- start in UTC or stored in user's timezone? Store as UTC
  end_dt DATETIME(3) NOT NULL,
  is_all_day TINYINT(1) DEFAULT 0,
  timezone VARCHAR(64) DEFAULT 'UTC',     -- original timezone of the event
  status ENUM('confirmed','tentative','cancelled') DEFAULT 'confirmed',
  visibility ENUM('default','private','public') DEFAULT 'default',
  color_override CHAR(7) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(3),
  -- recurrence fields
  is_recurring TINYINT(1) DEFAULT 0,
  rrule TEXT NULL,                         -- store RFC5545 RRULE string or custom JSON
  recur_end_dt DATETIME(3) NULL,           -- optional end date for recurrence
  recur_exdates JSON NULL,                 -- JSON array of excluded datetimes (ISO)
  recur_rdates JSON NULL,                  -- JSON array of extra datetimes (ISO)
  FOREIGN KEY (calendar_id) REFERENCES calendars(id) ON DELETE CASCADE,
  FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_events_calendar (calendar_id),
  INDEX idx_events_start (start_dt),
  INDEX idx_events_end (end_dt)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- event_instances: materialized occurrences for fast querying
-- (populated by application / scheduled job to expand recurring events)
-- ----------------------------------------------------------------
CREATE TABLE event_instances (
  id BINARY(16) NOT NULL PRIMARY KEY,
  event_id BINARY(16) NOT NULL,          -- master event
  calendar_id BINARY(16) NOT NULL,
  occurrence_start DATETIME(3) NOT NULL,
  occurrence_end DATETIME(3) NOT NULL,
  is_exception TINYINT(1) DEFAULT 0,      -- generated from EXDATE or edit exception
  original_event_id BINARY(16) NULL,      -- if this instance is detached (edited single occurrence)
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(3),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (calendar_id) REFERENCES calendars(id) ON DELETE CASCADE,
  INDEX idx_instances_calendar_start (calendar_id, occurrence_start),
  INDEX idx_instances_event (event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- reminders: multiple reminders per event
-- ----------------------------------------------------------------
CREATE TABLE reminders (
  id BINARY(16) NOT NULL PRIMARY KEY,
  event_id BINARY(16) NOT NULL,
  type ENUM('popup','email','sms','push') DEFAULT 'popup',
  minutes_before INT NOT NULL,             -- minutes before start (negative allowed for after?)
  relative BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  INDEX idx_reminders_event (event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- participants / attendees
-- ----------------------------------------------------------------
CREATE TABLE participants (
  id BINARY(16) NOT NULL PRIMARY KEY,
  event_id BINARY(16) NOT NULL,
  email VARCHAR(255) NULL,
  user_id BINARY(16) NULL,
  display_name VARCHAR(255) NULL,
  role ENUM('required','optional','resource') DEFAULT 'required',
  response_status ENUM('needsAction','accepted','declined','tentative','delegated') DEFAULT 'needsAction',
  invited_at TIMESTAMP(3) NULL,
  responded_at TIMESTAMP(3) NULL,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_participants_event (event_id),
  INDEX idx_participants_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- attachments: uploaded files for events
-- ----------------------------------------------------------------
CREATE TABLE attachments (
  id BINARY(16) NOT NULL PRIMARY KEY,
  event_id BINARY(16) NOT NULL,
  filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(255) NULL,
  file_size BIGINT DEFAULT 0,
  storage_path VARCHAR(1024) NULL,   -- path in storage (S3 / local)
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  INDEX idx_attachments_event (event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- calendar_shares: share calendar with users / public links
-- ----------------------------------------------------------------
CREATE TABLE calendar_shares (
  id BINARY(16) NOT NULL PRIMARY KEY,
  calendar_id BINARY(16) NOT NULL,
  share_type ENUM('user','group','public_link') NOT NULL,
  target_id BINARY(16) NULL,         -- user id or group id
  email VARCHAR(255) NULL,           -- if sharing by email
  role ENUM('reader','writer','owner') DEFAULT 'reader',
  token CHAR(64) NULL,               -- for public_link
  expires_at DATETIME(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (calendar_id) REFERENCES calendars(id) ON DELETE CASCADE,
  INDEX idx_shares_calendar (calendar_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- user_settings: per-user options
-- ----------------------------------------------------------------
CREATE TABLE user_settings (
  id BINARY(16) NOT NULL PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  key_name VARCHAR(128) NOT NULL,
  value JSON NULL,
  updated_at TIMESTAMP(3) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(3),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_user_setting (user_id, key_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- auth_sessions / tokens
-- ----------------------------------------------------------------
CREATE TABLE auth_sessions (
  id BINARY(16) NOT NULL PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  refresh_token_hash VARCHAR(255) NULL,   -- hashed refresh token for verification
  ip_address VARCHAR(64) NULL,
  user_agent VARCHAR(1024) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at DATETIME(3) NULL,
  revoked_at DATETIME(3) NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_sessions_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- notifications queue (for server / worker)
-- ----------------------------------------------------------------
CREATE TABLE notifications (
  id BINARY(16) NOT NULL PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  event_id BINARY(16) NULL,
  channel ENUM('email','push','sms','inbox') DEFAULT 'inbox',
  payload JSON NULL,
  status ENUM('pending','sent','failed') DEFAULT 'pending',
  retry_count INT DEFAULT 0,
  scheduled_at DATETIME(3) NULL,
  sent_at DATETIME(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notifications_user (user_id),
  INDEX idx_notifications_status (status, scheduled_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- audit_logs: who did what (immutable append)
-- ----------------------------------------------------------------
CREATE TABLE audit_logs (
  id BINARY(16) NOT NULL PRIMARY KEY,
  actor_id BINARY(16) NULL,
  actor_email VARCHAR(255) NULL,
  action VARCHAR(100) NOT NULL,
  object_type VARCHAR(50) NULL,
  object_id BINARY(16) NULL,
  meta JSON NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_audit_actor (actor_id),
  INDEX idx_audit_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- imports_exports: track ics imports/exports
-- ----------------------------------------------------------------
CREATE TABLE imports_exports (
  id BINARY(16) NOT NULL PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  type ENUM('import','export') NOT NULL,
  status ENUM('pending','completed','failed') DEFAULT 'pending',
  file_path VARCHAR(1024) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at DATETIME(3) NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_imports_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- tags & event_tags: optional tagging system
-- ----------------------------------------------------------------
CREATE TABLE tags (
  id BINARY(16) NOT NULL PRIMARY KEY,
  owner_id BINARY(16) NOT NULL,
  name VARCHAR(128) NOT NULL,
  color CHAR(7) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_tag_owner_name (owner_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_tags (
  id BINARY(16) NOT NULL PRIMARY KEY,
  event_id BINARY(16) NOT NULL,
  tag_id BINARY(16) NOT NULL,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,
  INDEX idx_event_tags_event (event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- misc: server-side settings or feature flags
-- ----------------------------------------------------------------
CREATE TABLE server_settings (
  name VARCHAR(128) NOT NULL PRIMARY KEY,
  value JSON NULL,
  updated_at TIMESTAMP(3) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------
-- Views (example): event occurrences view (joins instance->event)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_event_occurrences AS
SELECT
  BIN_TO_UUID(ei.id) AS instance_id,
  BIN_TO_UUID(e.id) AS event_id,
  ei.occurrence_start,
  ei.occurrence_end,
  e.title,
  e.description,
  e.location,
  e.is_all_day,
  e.timezone,
  c.title AS calendar_title,
  BIN_TO_UUID(c.id) AS calendar_id
FROM event_instances ei
JOIN events e ON ei.event_id = e.id
JOIN calendars c ON ei.calendar_id = c.id;

-- ----------------------------------------------------------------
-- Triggers: audit create/update/delete for events (example)
-- Keep these lightweight — store minimal info to audit_logs.
-- ----------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER trg_events_after_insert
AFTER INSERT ON events
FOR EACH ROW
BEGIN
  INSERT INTO audit_logs (id, actor_id, actor_email, action, object_type, object_id, meta)
  VALUES (UUID_TO_BIN(UUID()), NULL, NULL, 'event.create', 'event', NEW.id,
          JSON_OBJECT('title', NEW.title, 'calendar_id', BIN_TO_UUID(NEW.calendar_id)));
END$$

CREATE TRIGGER trg_events_after_update
AFTER UPDATE ON events
FOR EACH ROW
BEGIN
  INSERT INTO audit_logs (id, actor_id, action, object_type, object_id, meta)
  VALUES (UUID_TO_BIN(UUID()), NULL, 'event.update', 'event', NEW.id,
          JSON_OBJECT('old_start', OLD.start_dt, 'new_start', NEW.start_dt));
END$$

CREATE TRIGGER trg_events_after_delete
AFTER DELETE ON events
FOR EACH ROW
BEGIN
  INSERT INTO audit_logs (id, actor_email, action, object_type, object_id, meta)
  VALUES (UUID_TO_BIN(UUID()), NULL, 'event.delete', 'event', OLD.id,
          JSON_OBJECT('title', OLD.title, 'calendar_id', BIN_TO_UUID(OLD.calendar_id)));
END$$
DELIMITER ;

-- ----------------------------------------------------------------
-- Helper: disable FK checks back to normal
-- ----------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 1;
