# TheBoosh.Zone - Backend Error Handling Standardization Plan

**Created**: November 10, 2025
**Status**: Planning Phase
**Priority**: High (Contains Critical Security and Data Integrity Bugs)
**Estimated Effort**: 12 weeks (Critical fixes in first 2 weeks)

---

## Executive Summary

The TheBoosh.Zone codebase demonstrates solid security practices but suffers from **significant inconsistencies in error handling patterns** across 13 files with **57 eval blocks**, **68 `return undef` statements**, and **9 warn statements**. This document provides a comprehensive analysis and 4-phase implementation plan to standardize error handling.

### Critical Issues Identified:
- **Authentication security bug** in Auth.pm _get_user_by_id() method
- **Data integrity risks** from unsafe transaction rollbacks
- **Inconsistent error return patterns** across models and controllers
- **Loss of error context** making production debugging difficult
- **No structured exception handling** or request tracing

---

## Problem Analysis

### Current Error Handling Patterns

#### **1. Model Layer Inconsistencies**

**Pattern 1: Return `undef` on error**
```perl
# Article.pm, Tag.pm - Most common pattern
my $dbh = $self->_get_dbh();
return undef unless $dbh;  # Early return pattern

eval { ... };
if ($@) {
    if ($self->{logger}) {
        $self->{logger}->error("Failed to fetch articles: $@");
    }
    $dbh->disconnect() if $dbh;
    return undef;  # Generic error return
}
```

**Pattern 2: Return `0` or `[]` for specific cases**
```perl
# Tag.pm - Count methods return 0
return 0;  # For count/numeric methods

# Article.pm - Collection methods return []
return [];  # For array/collection methods
```

**Pattern 3: `warn` instead of logging**
```perl
# Media.pm - Uses warn instead of logger
warn "Error creating media record: $@";
return undef;
```

**ISSUE**: Three different error return conventions make error handling unpredictable.

#### **2. Critical Bugs Found**

**🔴 CRITICAL: Auth.pm _get_user_by_id() Return Value Bug**
```perl
# lib/HelloPerld/Controller/Auth.pm, lines 268-283
eval {
    my $sth = $dbh->prepare($sql);
    $sth->execute($user_id);
    my $user = $sth->fetchrow_hashref();
    $dbh->disconnect();
    return $user;  # ❌ This doesn't actually return from the sub!
};

if ($@) {
    $self->app->logger_instance->error("User lookup failed: $@");
    $dbh->disconnect() if $dbh;
    return undef;
}
# ❌ Missing: $user is lost, function always returns undef
```

**Impact**: Password change operations could fail silently, potential authentication bypass.

**🔴 CRITICAL: Unsafe Transaction Rollbacks**
```perl
# Article.pm, Media.pm - Unsafe pattern
if ($@) {
    $dbh->rollback();  # ❌ Could throw another exception, masking original error
    # ... error handling
}

# vs. Tag.pm - Safe pattern
if ($@) {
    if ($dbh) {
        eval { $dbh->rollback(); };  # ✅ Safe rollback
        if ($@) {
            if ($self->{logger}) {
                $self->{logger}->error("Rollback failed: $@");
            }
        }
    }
}
```

**Impact**: Database locks, orphaned data, potential data corruption.

#### **3. API Response Inconsistencies**

**Standard Format** (Most controllers):
```perl
return $self->render(json => {
    success => 0,
    error => 'Error message here'
}, status => 400);
```

**Auth-Specific Format**:
```perl
return $self->render(json => {
    authenticated => 0  # Different key, no success field
});
```

**Health Check Format**:
```perl
$self->render(json => {
    status => 'unhealthy',  # Different key structure
    timestamp => $timestamp
}, status => 503);
```

**ISSUE**: Three different response formats across controllers.

#### **4. Lost Error Context**

**Controller Pattern**:
```perl
my $created_article = $article_model->create($article_data);

unless ($created_article) {
    return $self->render(json => {
        success => 0,
        error => 'Failed to create article'  # ❌ Generic message, lost specific error
    }, status => 500);
}
```

**ISSUE**: Model returns `undef` but controller can't determine if failure was:
- Database connection failure
- Constraint violation
- Input validation failure
- Transaction rollback

All failures become generic "Failed to create" message.

---

## Current State Statistics

| Component | Files | eval Blocks | return undef | warn Statements | Issues |
|-----------|-------|-------------|--------------|-----------------|---------|
| **Models** | 4 | 43 | 52 | 6 | High |
| **Controllers** | 5 | 12 | 14 | 2 | Medium |
| **Database** | 1 | 2 | 2 | 1 | Low |
| **Logger** | 3 | 0 | 0 | 0 | Low |
| **TOTALS** | **13** | **57** | **68** | **9** | |

### Error Return Value Patterns by File:

| File | undef Returns | Zero Returns | Array Returns | warn Usage |
|------|---------------|--------------|---------------|-------------|
| Article.pm | 8 | 1 | 2 | 0 |
| Tag.pm | 8 | 5 | 4 | 0 |
| Media.pm | 5 | 0 | 0 | 6 |
| Auth.pm | 6 | 0 | 0 | 0 |
| Health.pm | 2 | 0 | 0 | 0 |

---

## 4-Phase Implementation Plan

### **Phase 1: Foundation - Critical Fixes (Weeks 1-2)**
**Goal**: Fix critical bugs and establish error handling standards

#### **Week 1: Critical Bug Fixes**

**1.1 Fix Auth.pm Return Value Bug** (15 minutes)
```perl
# BEFORE (broken):
eval {
    # ... database operations ...
    return $user;  # Lost in eval
};

# AFTER (fixed):
my $user;
eval {
    # ... database operations ...
    $user = $sth->fetchrow_hashref();
    $sth->finish();
    $dbh->disconnect();
};
if ($@) {
    # ... error handling ...
    return undef;
}
return $user;  # Properly returns from function
```

**1.2 Fix Unsafe Rollback Patterns** (2 hours)
- Update Article.pm and Media.pm to use safe rollback pattern
- Add nested eval for rollback operations
- Log rollback failures separately

**1.3 Create Error Response Helper** (4 hours)
```perl
package HelloPerld::Util::ErrorResponse;

sub error_response {
    my ($controller, $type, $message, %options) = @_;

    my %status_codes = (
        validation => 400,
        not_found => 404,
        unauthorized => 401,
        forbidden => 403,
        conflict => 409,
        rate_limit => 429,
        server_error => 500,
    );

    my $status = $status_codes{$type} || 500;

    return $controller->render(json => {
        success => 0,
        error => $message,
        error_type => $type,
        error_code => $options{code},
        details => $options{details},
        request_id => $controller->req->request_id,
        timestamp => time(),
    }, status => $status);
}
```

**1.4 Add Correlation ID Middleware** (8 hours)
```perl
# In HelloPerld.pm startup
$self->hook(before_dispatch => sub {
    my $c = shift;
    my $request_id = $c->req->headers->header('X-Request-ID')
                     || _generate_uuid();
    $c->req->request_id($request_id);
    $c->res->headers->header('X-Request-ID' => $request_id);
});
```

#### **Week 2: Standards Foundation**

**2.1 Create Base Model Error Structure** (8 hours)
```perl
package HelloPerld::Model::ErrorResult;
use Moo;

has 'success' => (is => 'ro', default => 0);
has 'error_type' => (is => 'ro', required => 1);  # connection, query, constraint
has 'message' => (is => 'ro', required => 1);
has 'details' => (is => 'ro');
has 'sql_state' => (is => 'ro');  # PostgreSQL SQLSTATE
has 'operation' => (is => 'ro');  # create, update, delete, fetch
has 'context' => (is => 'ro');    # Additional debugging info
```

**2.2 Update Media.pm warn → logger** (2 hours)
- Replace all 6 `warn` statements with proper logger calls
- Add request context to log messages
- Ensure consistent error return format

**2.3 Add Transaction Helper Method** (8 hours)
```perl
package HelloPerld::Model::Base;

sub with_transaction {
    my ($self, $code) = @_;

    my $dbh = $self->_get_dbh();
    return $self->_connection_error() unless $dbh;

    my $result;
    eval {
        $dbh->begin_work();
        $result = $code->($dbh);
        $dbh->commit();
        $dbh->disconnect();
    };

    if (my $err = $@) {
        eval { $dbh->rollback() };
        if (my $rollback_err = $@) {
            $self->_log_error("Rollback failed: $rollback_err");
        }
        $dbh->disconnect() if $dbh;
        return $self->_database_error($err);
    }

    return $result;
}
```

**Phase 1 Deliverables:**
- ✅ Critical authentication bug fixed
- ✅ Data integrity bugs fixed
- ✅ Error response standard established
- ✅ Request correlation IDs implemented
- ✅ Safe transaction pattern available

---

### **Phase 2: Consistency - Apply Standards (Weeks 3-4)**
**Goal**: Apply standards consistently across all controllers and models

#### **Week 3: Controller Standardization**

**3.1 Update All Controllers to Use Error Response Helper** (16 hours)
- **Articles.pm**: 8 error response locations
- **Tags.pm**: 6 error response locations
- **Media.pm**: 7 error response locations
- **Auth.pm**: 4 error response locations (preserve authentication flow)
- **Health.pm**: 2 error response locations

**Example Migration**:
```perl
# BEFORE:
return $self->render(json => {
    success => 0,
    error => 'Failed to create article'
}, status => 500);

# AFTER:
return error_response($self, 'server_error',
    'Failed to create article',
    details => $error->details
);
```

**3.2 Standardize HTTP Status Codes** (4 hours)

| Scenario | Old Status | New Status | Controllers Affected |
|----------|------------|------------|---------------------|
| Validation errors | 400 | 422 | Articles, Tags, Media |
| Missing required fields | 400 | 422 | All controllers |
| Resource conflicts | Various | 409 | Tags (duplicate names) |
| Authentication required | 401 | 401 | Consistent |
| CSRF failures | 403 | 403 | Consistent |
| Rate limiting | 429 | 429 | Auth only → All admin |

**3.3 Add Request Context to All Log Messages** (8 hours)
```perl
# Standard log format for all errors:
$self->app->logger_instance->error({
    request_id => $c->req->request_id,
    operation => 'article.create',
    user_id => $c->session('admin_user_id'),
    error_type => $error->type,
    message => $error->message,
    duration_ms => $elapsed_time,
});
```

#### **Week 4: Model Standardization**

**4.1 Update All Models to Use Standardized Error Returns** (16 hours)

**Article.pm Updates** (6 hours):
- 8 methods returning `undef` → ErrorResult objects
- Add operation context to all database errors
- Preserve existing return types for success cases

**Tag.pm Updates** (6 hours):
- 8 methods returning `undef` → ErrorResult objects
- 5 count methods: preserve `0` for empty results, ErrorResult for errors
- 4 collection methods: preserve `[]` for empty, ErrorResult for errors

**Media.pm Updates** (4 hours):
- 5 methods returning `undef` → ErrorResult objects
- Replace warn statements with structured errors

**4.2 Update Integration Tests for New Error Format** (8 hours)
- Update test expectations for new error response format
- Add tests for request correlation IDs
- Verify backward compatibility for success responses

**Phase 2 Deliverables:**
- ✅ All controllers use standardized error responses
- ✅ Consistent HTTP status codes across API
- ✅ All models return structured error objects
- ✅ Request tracing available in all logs
- ✅ All integration tests passing

---

### **Phase 3: Architecture - Structured Approach (Weeks 5-8)**
**Goal**: Implement proper error handling architecture

#### **Weeks 5-6: Exception Class Hierarchy**

**5.1 Create Exception Class Hierarchy** (16 hours)
```perl
# Base exception class
package HelloPerld::Exception::Base;
use Moo;
use overload '""' => 'as_string';

has 'message' => (is => 'ro', required => 1);
has 'context' => (is => 'ro', default => sub { {} });
has 'request_id' => (is => 'ro');
has 'timestamp' => (is => 'ro', default => sub { time() });

# Validation exceptions
package HelloPerld::Exception::ValidationError;
use Moo;
extends 'HelloPerld::Exception::Base';

package HelloPerld::Exception::RequiredFieldMissing;
use Moo;
extends 'HelloPerld::Exception::ValidationError';
has 'field' => (is => 'ro', required => 1);

# Database exceptions
package HelloPerld::Exception::DatabaseError;
use Moo;
extends 'HelloPerld::Exception::Base';
has 'sql_state' => (is => 'ro');
has 'operation' => (is => 'ro');

package HelloPerld::Exception::ConnectionFailed;
use Moo;
extends 'HelloPerld::Exception::DatabaseError';

package HelloPerld::Exception::UniqueViolation;
use Moo;
extends 'HelloPerld::Exception::DatabaseError';
has 'constraint' => (is => 'ro');
has 'conflicting_value' => (is => 'ro');

# Resource exceptions
package HelloPerld::Exception::NotFound;
use Moo;
extends 'HelloPerld::Exception::Base';
has 'resource_type' => (is => 'ro');
has 'resource_id' => (is => 'ro');

# Authentication exceptions
package HelloPerld::Exception::AuthenticationError;
use Moo;
extends 'HelloPerld::Exception::Base';

package HelloPerld::Exception::InvalidCredentials;
use Moo;
extends 'HelloPerld::Exception::AuthenticationError';
has 'username' => (is => 'ro');
```

**5.2 Update Models to Throw Typed Exceptions** (16 hours)

**Before**:
```perl
eval {
    my $sth = $dbh->prepare($sql);
    $sth->execute(@params);
    # ...
};
if ($@) {
    $self->_log_error("Database error: $@");
    return undef;
}
```

**After**:
```perl
eval {
    my $sth = $dbh->prepare($sql);
    $sth->execute(@params);
    # ...
};
if (my $err = $@) {
    if ($err =~ /duplicate key value violates unique constraint "(\w+)"/) {
        HelloPerld::Exception::UniqueViolation->throw(
            message => "Resource already exists",
            constraint => $1,
            operation => 'create',
            context => { params => \@params }
        );
    } else {
        HelloPerld::Exception::DatabaseError->throw(
            message => "Database operation failed",
            operation => 'create',
            context => { error => $err, params => \@params }
        );
    }
}
```

**5.3 Add Centralized Error Handler Middleware** (8 hours)
```perl
# In HelloPerld.pm
$self->hook(around_action => sub {
    my ($next, $c, $action, $last) = @_;

    eval { $next->() };

    if (my $err = $@) {
        if ($err->isa('HelloPerld::Exception::Base')) {
            return $c->handle_structured_error($err);
        } else {
            return $c->handle_unstructured_error($err);
        }
    }
});

# Error handler methods
sub handle_structured_error {
    my ($c, $exception) = @_;

    my %type_mapping = (
        'HelloPerld::Exception::ValidationError' => 'validation',
        'HelloPerld::Exception::NotFound' => 'not_found',
        'HelloPerld::Exception::UniqueViolation' => 'conflict',
        'HelloPerld::Exception::AuthenticationError' => 'unauthorized',
        'HelloPerld::Exception::DatabaseError' => 'server_error',
    );

    my $error_type = $type_mapping{ref $exception} || 'server_error';

    return error_response($c, $error_type, $exception->message,
        details => $exception->context,
        code => ref $exception
    );
}
```

#### **Weeks 7-8: Performance and Monitoring**

**7.1 Implement Connection Pooling** (16 hours)
```perl
# Add DBIx::Connector to Makefile.PL
package HelloPerld::Database::Postgres;
use DBIx::Connector;

our $CONNECTOR;

sub get_connector {
    my ($logger, %options) = @_;

    unless ($CONNECTOR) {
        my $dsn = _build_dsn(%options);
        my $user = $options{user} || $ENV{POSTGRES_USER};
        my $password = $options{password} || $ENV{POSTGRES_PASSWORD};

        $CONNECTOR = DBIx::Connector->new(
            $dsn, $user, $password,
            {
                RaiseError => 1,
                AutoCommit => 1,
                PrintError => 0,
                pg_enable_utf8 => 1,
            },
            {
                mode => 'fixup',
                disconnect_on_destroy => 0,
            }
        );
    }

    return $CONNECTOR;
}

# Update _get_dbh in Model::Base
sub _get_dbh {
    my ($self) = @_;

    my $conn = HelloPerld::Database::Postgres::get_connector($self->{logger});
    return $conn->dbh;  # Returns pooled connection, no disconnect needed
}
```

**7.2 Add Error Rate Monitoring** (8 hours)
```perl
# Prometheus metrics for errors
package HelloPerld::Metrics::Errors;

use Prometheus::Tiny::Shared;

my $prom = Prometheus::Tiny::Shared->new;

sub record_error {
    my ($error_type, $operation, $controller) = @_;

    $prom->inc('http_errors_total', {
        type => $error_type,
        operation => $operation,
        controller => $controller,
    });
}

sub record_database_error {
    my ($operation, $sql_state) = @_;

    $prom->inc('database_errors_total', {
        operation => $operation,
        sql_state => $sql_state || 'unknown',
    });
}
```

**7.3 Update All Tests for Exception Handling** (8 hours)
- Update unit tests to expect exceptions instead of undef returns
- Add integration tests for error scenarios
- Test exception propagation through middleware
- Verify error metrics collection

**Phase 3 Deliverables:**
- ✅ Complete exception class hierarchy implemented
- ✅ All models throw typed exceptions
- ✅ Centralized error handling middleware
- ✅ Connection pooling for better performance
- ✅ Error rate monitoring and metrics
- ✅ All tests updated and passing

---

### **Phase 4: Resilience - Production Hardening (Weeks 9-12)**
**Goal**: Handle edge cases and improve production reliability

#### **Weeks 9-10: Retry Logic and Circuit Breaking**

**9.1 Add Retry Logic for Transient Errors** (16 hours)
```perl
package HelloPerld::Util::Retry;
use Time::HiRes qw(sleep);

sub with_retry {
    my (%options) = @_;

    my $code = $options{code} or die "code is required";
    my $max_attempts = $options{max_attempts} || 3;
    my $base_delay = $options{base_delay} || 0.1;
    my $retry_if = $options{retry_if} || sub {
        my $err = shift;
        return $err->isa('HelloPerld::Exception::ConnectionFailed') ||
               $err->isa('HelloPerld::Exception::TransientError');
    };

    for my $attempt (1..$max_attempts) {
        eval { return $code->() };

        if (my $err = $@) {
            last if $attempt == $max_attempts;
            last unless $retry_if->($err);

            my $delay = $base_delay * (2 ** ($attempt - 1));  # Exponential backoff
            sleep($delay);

            # Log retry attempt
            if ($options{logger}) {
                $options{logger}->warn("Retrying operation (attempt $attempt/$max_attempts): " . $err->message);
            }
        } else {
            return;  # Success
        }
    }

    die $@;  # Failed after all retries
}

# Usage in models:
my $result = with_retry(
    code => sub { $self->_database_operation() },
    max_attempts => 3,
    retry_if => sub { $_[0]->isa('HelloPerld::Exception::ConnectionFailed') },
    logger => $self->{logger},
);
```

**9.2 Parse PostgreSQL Error Codes** (8 hours)
```perl
package HelloPerld::Database::PostgreSQLErrors;

my %error_codes = (
    '23505' => 'UniqueViolation',      # duplicate key value
    '23503' => 'ForeignKeyViolation',  # foreign key constraint
    '23502' => 'NotNullViolation',     # not null constraint
    '42P01' => 'UndefinedTable',       # table does not exist
    '42703' => 'UndefinedColumn',      # column does not exist
    '08006' => 'ConnectionFailure',    # connection failure
    '08003' => 'ConnectionNotExist',   # connection does not exist
    '40001' => 'SerializationFailure', # serialization failure
    '40P01' => 'DeadlockDetected',     # deadlock detected
);

sub parse_database_error {
    my ($err_string) = @_;

    # Extract SQLSTATE from error message
    if ($err_string =~ /ERROR:\s+(.+?)\s+\(SQLSTATE\s+(\w{5})\)/) {
        my ($message, $sqlstate) = ($1, $2);
        my $error_class = $error_codes{$sqlstate} || 'DatabaseError';

        return ("HelloPerld::Exception::$error_class", {
            message => $message,
            sql_state => $sqlstate,
        });
    }

    return ('HelloPerld::Exception::DatabaseError', {
        message => $err_string,
    });
}
```

**9.3 Add Circuit Breaker for Database** (8 hours)
```perl
package HelloPerld::Util::CircuitBreaker;
use Time::HiRes qw(time);

sub new {
    my ($class, %options) = @_;

    return bless {
        failure_threshold => $options{failure_threshold} || 5,
        timeout => $options{timeout} || 30,
        state => 'closed',  # closed, open, half_open
        failures => 0,
        last_failure_time => 0,
    }, $class;
}

sub call {
    my ($self, $code) = @_;

    if ($self->{state} eq 'open') {
        if (time() - $self->{last_failure_time} > $self->{timeout}) {
            $self->{state} = 'half_open';
        } else {
            HelloPerld::Exception::ServiceUnavailable->throw(
                message => "Circuit breaker is open"
            );
        }
    }

    eval {
        my $result = $code->();

        if ($self->{state} eq 'half_open') {
            $self->{state} = 'closed';
            $self->{failures} = 0;
        }

        return $result;
    };

    if (my $err = $@) {
        $self->_record_failure();
        die $err;
    }
}

sub _record_failure {
    my ($self) = @_;

    $self->{failures}++;
    $self->{last_failure_time} = time();

    if ($self->{failures} >= $self->{failure_threshold}) {
        $self->{state} = 'open';
    }
}
```

#### **Weeks 11-12: Monitoring and Documentation**

**11.1 Implement Graceful Degradation** (16 hours)
```perl
package HelloPerld::Service::GracefulDegradation;

sub fallback_response {
    my ($controller, $error_type) = @_;

    my %fallbacks = (
        'database_unavailable' => {
            message => 'Service temporarily unavailable. Please try again later.',
            status => 503,
            retry_after => 60,
        },
        'external_service_down' => {
            message => 'Some features may be temporarily unavailable.',
            status => 200,  # Partial content
            degraded => 1,
        },
        'rate_limited' => {
            message => 'Too many requests. Please slow down.',
            status => 429,
            retry_after => 300,
        },
    );

    my $fallback = $fallbacks{$error_type} || $fallbacks{'database_unavailable'};

    my $response = {
        success => 0,
        error => $fallback->{message},
        degraded => $fallback->{degraded} || 0,
        timestamp => time(),
    };

    $controller->res->headers->header('Retry-After' => $fallback->{retry_after})
        if $fallback->{retry_after};

    return $controller->render(json => $response, status => $fallback->{status});
}
```

**11.2 Create Error Tracking Dashboard** (8 hours)

**Grafana Dashboard Configuration**:
```json
{
  "dashboard": {
    "title": "Error Tracking Dashboard",
    "panels": [
      {
        "title": "Error Rate by Type",
        "type": "stat",
        "targets": [{
          "expr": "rate(http_errors_total[5m])",
          "legendFormat": "{{type}}"
        }]
      },
      {
        "title": "Database Errors",
        "type": "graph",
        "targets": [{
          "expr": "database_errors_total",
          "legendFormat": "{{sql_state}}"
        }]
      },
      {
        "title": "Response Time P95",
        "type": "graph",
        "targets": [{
          "expr": "histogram_quantile(0.95, http_request_duration_seconds_bucket)"
        }]
      },
      {
        "title": "Circuit Breaker State",
        "type": "stat",
        "targets": [{
          "expr": "circuit_breaker_state",
          "legendFormat": "{{service}}"
        }]
      }
    ]
  }
}
```

**Alert Configuration**:
```yaml
# alerts.yml
groups:
- name: error_handling
  rules:
  - alert: HighErrorRate
    expr: rate(http_errors_total[5m]) > 0.1
    for: 5m
    annotations:
      summary: "High error rate detected"

  - alert: DatabaseConnectionFailure
    expr: database_errors_total{sql_state="08006"} > 0
    for: 1m
    annotations:
      summary: "Database connection failures detected"

  - alert: CircuitBreakerOpen
    expr: circuit_breaker_state == 1
    for: 0s
    annotations:
      summary: "Circuit breaker is open for {{$labels.service}}"
```

**11.3 Add Comprehensive Error Documentation** (8 hours)

**Error Code Reference** (`docs/ERROR_CODES.md`):
```markdown
# Error Code Reference

## Validation Errors (4xx)

### 400 - Bad Request
- Invalid JSON format
- Malformed request parameters

### 422 - Unprocessable Entity
- **VAL001**: Required field missing
- **VAL002**: Invalid field format
- **VAL003**: Value out of allowed range

### 409 - Conflict
- **CON001**: Resource already exists
- **CON002**: Resource currently in use

## Server Errors (5xx)

### 500 - Internal Server Error
- **DB001**: Database connection failed
- **DB002**: Transaction rollback failed
- **DB003**: Constraint violation

### 503 - Service Unavailable
- **SVC001**: Database temporarily unavailable
- **SVC002**: Circuit breaker open
```

**Troubleshooting Guide** (`docs/TROUBLESHOOTING.md`):
```markdown
# Error Handling Troubleshooting Guide

## Common Error Scenarios

### "Database connection failed" (DB001)
**Symptoms**: 500 errors, connection timeouts
**Causes**: Database server down, network issues, connection pool exhaustion
**Resolution**:
1. Check database server status
2. Verify connection pool configuration
3. Check network connectivity

### "Circuit breaker open" (SVC002)
**Symptoms**: 503 errors, service unavailable messages
**Causes**: Multiple consecutive failures to external service
**Resolution**:
1. Wait for circuit breaker timeout (30 seconds)
2. Check external service status
3. Review error logs for root cause
```

**Phase 4 Deliverables:**
- ✅ Retry logic for transient failures
- ✅ PostgreSQL error code parsing
- ✅ Circuit breaker for external dependencies
- ✅ Graceful degradation strategies
- ✅ Comprehensive error monitoring dashboard
- ✅ Complete error documentation and troubleshooting guides

---

## Expected Outcomes

### **Code Quality Improvements**
- **Zero `warn` statements** in production code
- **100% standardized API error responses** across all endpoints
- **All models throw typed exceptions** instead of returning `undef`
- **100% of logs include correlation IDs** for request tracing
- **Zero unsafe transaction rollback patterns**

### **Operational Benefits**
- **50% reduction in Mean Time To Repair (MTTR)** through better error visibility
- **Request tracing** through complete application stack via correlation IDs
- **Proactive error monitoring** with Grafana dashboards and alerts
- **Circuit breaker protection** preventing cascade failures
- **Retry logic** for transient errors improving reliability

### **Developer Experience**
- **Clear error types** enable programmatic error handling
- **Consistent patterns** across all controllers and models
- **Better debugging** with structured logging and error context
- **Safe transaction handling** prevents data corruption
- **Comprehensive documentation** for error scenarios

### **User Experience**
- **Actionable error messages** instead of generic failures
- **Graceful degradation** when services are temporarily unavailable
- **Consistent API responses** for easier client integration
- **Better uptime** through resilience patterns

---

## Success Metrics

### **Phase 1 (Critical Fixes)**
- ✅ Auth.pm return value bug fixed (authentication security)
- ✅ All unsafe rollback patterns eliminated (data integrity)
- ✅ Error response helper implemented and tested
- ✅ Correlation ID middleware deployed

### **Phase 2 (Consistency)**
- ✅ All API endpoints use standardized error format
- ✅ HTTP status codes consistent across controllers
- ✅ All models return structured error objects
- ✅ Zero `warn` statements in codebase
- ✅ All integration tests pass with new error handling

### **Phase 3 (Architecture)**
- ✅ Exception class hierarchy complete
- ✅ All models throw typed exceptions
- ✅ Centralized error handler middleware functioning
- ✅ Connection pooling implemented (performance improvement)
- ✅ Error rate metrics collection working

### **Phase 4 (Resilience)**
- ✅ Retry logic handles transient failures
- ✅ Circuit breaker protects against cascade failures
- ✅ Error dashboard provides operational visibility
- ✅ Documentation complete for all error scenarios
- ✅ MTTR reduced by 50% (measured over 30 days)

---

## Risk Assessment and Mitigation

### **High Risk Items**
1. **Changing model return types** could break existing code
   - **Mitigation**: Gradual rollout with feature flags, comprehensive test coverage

2. **Exception handling middleware** could mask application bugs
   - **Mitigation**: Careful logging of all exceptions, monitoring for new error patterns

3. **Connection pooling** changes database behavior
   - **Mitigation**: Thorough testing in staging, gradual rollout, rollback plan

### **Medium Risk Items**
1. **API response format changes** could break clients
   - **Mitigation**: Version API responses, maintain backward compatibility during transition

2. **Transaction helper** changes could affect data consistency
   - **Mitigation**: Extensive integration testing, database validation

### **Low Risk Items**
1. **Correlation ID addition** is purely additive
2. **Error logging improvements** don't change application behavior
3. **Documentation updates** have no code impact

### **Rollback Plans**
- **Feature flags** allow instant disabling of new error handling
- **Database migrations** are all backward compatible
- **API versioning** allows clients to use old response formats
- **Monitoring** detects issues early for rapid rollback decisions

---

## Resource Requirements

### **Timeline**: 12 weeks total
- **Weeks 1-2**: Critical fixes (immediate value)
- **Weeks 3-4**: Standardization (consistency value)
- **Weeks 5-8**: Architecture improvements (scalability value)
- **Weeks 9-12**: Production hardening (reliability value)

### **Personnel**
- **1 Senior Perl Developer** (full-time for 12 weeks)
- **0.5 QA Engineer** (for testing and validation)
- **0.25 DevOps Engineer** (for monitoring and deployment)

### **Dependencies**
- **Database access** for connection pooling testing
- **Staging environment** for integration testing
- **Monitoring infrastructure** (Prometheus/Grafana) for metrics

### **Budget Considerations**
- **No additional infrastructure costs** (uses existing monitoring)
- **No new third-party dependencies** (except DBIx::Connector)
- **Development time only** - no operational overhead

---

## Implementation Priority

### **Must Have (Weeks 1-2)**
- Fix critical authentication and data integrity bugs
- Establish error handling standards
- Add request tracing capability

### **Should Have (Weeks 3-6)**
- Apply standards consistently across codebase
- Implement exception class hierarchy
- Add centralized error handling

### **Could Have (Weeks 7-10)**
- Connection pooling for performance
- Retry logic for reliability
- Advanced monitoring and alerting

### **Won't Have (Future Consideration)**
- Error tracking service integration (Sentry/Rollbar)
- Machine learning for error pattern detection
- Advanced circuit breaker configurations

---

## Conclusion

This comprehensive error handling standardization plan addresses critical security and data integrity bugs while establishing a robust, scalable error handling architecture for TheBoosh.Zone.

The 4-phase approach ensures:
1. **Immediate risk mitigation** through critical bug fixes
2. **Consistent user experience** through API standardization
3. **Better operational visibility** through structured logging and monitoring
4. **Production resilience** through retry logic and circuit breaking

With an estimated 12-week timeline and focus on critical fixes in the first 2 weeks, this plan provides both immediate value and long-term architectural improvements that will support the application's growth and maintainability.

---

**Document Status**: Planning Phase
**Next Action**: Review and approval for Phase 1 implementation
**Last Updated**: November 10, 2025