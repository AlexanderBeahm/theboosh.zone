# TheBoosh.Zone Backend Testing

This directory contains the complete test suite for the Perl backend of TheBoosh.Zone.

## Test Framework

The backend uses the standard Perl testing ecosystem:

- **Test::More** - Core TAP-based testing framework
- **Test::Mojo** - Mojolicious web application testing
- **DBD::Mock** - Mock database driver for unit tests
- **Test::Exception** - Exception testing utilities
- **Test::MockModule** - Module mocking

## Directory Structure

```
t/
├── 00-load.t              # Module loading verification
├── unit/                  # Pure unit tests (mocked dependencies)
│   ├── model/
│   │   ├── article.t      # Article model tests
│   │   ├── tag.t          # Tag model tests
│   │   └── media.t        # Media model tests
│   └── database/
│       └── postgres.t     # Database utility tests
├── integration/           # Integration tests (real database)
│   └── controller/
│       ├── health.t       # Health check endpoint
│       ├── auth.t         # Authentication system
│       ├── articles.t     # Article CRUD operations
│       ├── tags.t         # Tag management
│       └── media.t        # Media upload/management
└── lib/
    └── TestHelper.pm      # Shared testing utilities
```

## Running Tests

### All Tests

```bash
./script/test
```

Or using prove directly:

```bash
prove -l -r -v t/
```

### Unit Tests Only

```bash
./script/test-unit
```

Unit tests use DBD::Mock and do not require database connectivity.

### Integration Tests Only

```bash
./script/test-integration
```

Integration tests require:
- PostgreSQL database (configured via environment variables)
- Admin user credentials (ADMIN_USERNAME, ADMIN_PASSWORD)

### Running Specific Test Files

```bash
prove -l -v t/unit/model/article.t
prove -l -v t/integration/controller/auth.t
```

### In Docker

```bash
docker exec thebooshzone-hello-perld-1 perl script/test
```

## Environment Variables

Integration tests use these environment variables:

```bash
# Database connection
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=thebooshzone_dev
POSTGRES_USER=theboosh_user
POSTGRES_PASSWORD=<your_password>

# Admin credentials (for integration tests)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=<your_admin_password>
```

## Writing New Tests

### Unit Tests (Models)

Unit tests mock database connections using DBD::Mock:

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::MockModule;
use lib 't/lib';
use TestHelper qw(mock_dbh mock_logger);

# Mock the database connection
my $postgres_mock = Test::MockModule->new('HelloPerld::Database::Postgres');
my $mock_dbh;
$postgres_mock->mock('get_connection', sub { return $mock_dbh; });

# Use the module
use_ok('HelloPerld::Model::YourModel');

subtest 'your test name' => sub {
    $mock_dbh = mock_dbh();
    
    # Set up mock result
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT/i,
        results => [
            ['id', 'name'],
            [1, 'Test']
        ]
    };
    
    # Run your test
    my $model = HelloPerld::Model::YourModel->new(logger => mock_logger());
    my $result = $model->get_something();
    
    # Assertions
    ok(defined $result, 'Returns result');
};

done_testing();
```

### Integration Tests (Controllers)

Integration tests use Test::Mojo for full HTTP testing:

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

my $t = Test::Mojo->new('HelloPerld');

subtest 'your endpoint test' => sub {
    $t->get_ok('/api/your/endpoint')
      ->status_is(200, 'Returns 200 OK')
      ->json_is('/key' => 'value', 'JSON matches expected')
      ->json_has('/another_key', 'Has expected field');
};

done_testing();
```

## Test Helpers

The `TestHelper` module (t/lib/TestHelper.pm) provides:

- `mock_dbh()` - Create mock database handle
- `mock_logger()` - Create test logger (ERROR level only)
- `create_test_article_data(%overrides)` - Generate test article data
- `create_test_tag_data(%overrides)` - Generate test tag data
- `create_test_media_data(%overrides)` - Generate test media data
- `create_test_user_data(%overrides)` - Generate test user data
- `setup_mock_session($t, %session)` - Setup authenticated session
- `mock_article_result(@articles)` - Create DBD::Mock article results
- `mock_tag_result(@tags)` - Create DBD::Mock tag results
- `mock_media_result(@media)` - Create DBD::Mock media results

## Critical Patterns from CLAUDE.md

When writing model tests, verify these patterns are followed:

### 1. No Return Inside Eval Blocks

```perl
# WRONG - return gets lost
eval {
    my $result = $dbh->selectrow_hashref($sql);
    return $result;  # Returns from eval, not function!
};

# CORRECT - store then return
my $result;
eval {
    $result = $dbh->selectrow_hashref($sql);
};
return $result;
```

### 2. Always Call finish() Before disconnect()

```perl
# WRONG - data corruption risk
eval {
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $result = $sth->fetchrow_hashref();
    $dbh->disconnect();  # Corrupts fetched data!
};

# CORRECT
eval {
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $result = $sth->fetchrow_hashref();
    $sth->finish();      # Clean up statement handle
    $dbh->disconnect();  # Safe to disconnect now
};
```

## Test Coverage

Current test coverage by module:

### Models (Unit Tests)
- Article model - 15+ test cases (get_all, get_by_slug, create, update, delete, etc.)
- Tag model - 20+ test cases (including find_or_create idempotency)
- Media model - 10+ test cases (CRUD operations, filtering)

### Controllers (Integration Tests)
- Health controller - 4 test cases
- Auth controller - 8+ test cases (login, logout, rate limiting, sessions)
- Articles controller - 10+ test cases (CRUD, auth, draft visibility)
- Tags controller - 8+ test cases (CRUD, search, usage counts)
- Media controller - 5+ test cases (listing, pagination, auth)

## Continuous Integration

To integrate tests into CI/CD:

```yaml
# Example GitHub Actions workflow
test:
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_DB: thebooshzone_test
        POSTGRES_USER: test_user
        POSTGRES_PASSWORD: test_pass
  steps:
    - uses: actions/checkout@v2
    - name: Install dependencies
      run: cpanm --installdeps .
    - name: Run tests
      run: ./script/test
      env:
        POSTGRES_HOST: localhost
        POSTGRES_DB: thebooshzone_test
        POSTGRES_USER: test_user
        POSTGRES_PASSWORD: test_pass
        ADMIN_USERNAME: testadmin
        ADMIN_PASSWORD: testpass123
```

## Troubleshooting

### Tests Fail with "Can't locate module"

Install test dependencies:

```bash
cpanm --installdeps .
# Or in Docker:
docker exec thebooshzone-hello-perld-1 cpanm --installdeps .
```

### Integration Tests Fail with Database Errors

1. Verify database is running:
   ```bash
   docker ps | grep postgres
   ```

2. Check environment variables:
   ```bash
   echo $POSTGRES_HOST $POSTGRES_DB
   ```

3. Test database connection:
   ```bash
   psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB
   ```

### Tests Pass Locally But Fail in CI

- Ensure all environment variables are set in CI configuration
- Verify database service is configured correctly
- Check that test dependencies are installed before running tests

## Contributing

When adding new features:

1. Write unit tests for models (t/unit/model/)
2. Write integration tests for controllers (t/integration/controller/)
3. Update this README if adding new patterns or helpers
4. Run full test suite before committing: `./script/test`

Follow the patterns established in existing tests for consistency.
