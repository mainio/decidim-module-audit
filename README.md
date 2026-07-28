# Decidim::Audit

[![Build Status](https://github.com/mainio/decidim-module-audit/actions/workflows/ci_audit.yml/badge.svg)](https://github.com/mainio/decidim-module-audit/actions)
[![codecov](https://codecov.io/gh/mainio/decidim-module-audit/branch/main/graph/badge.svg)](https://codecov.io/gh/mainio/decidim-module-audit)

Adds audit logging capabilities to the platform in order to improve specific
auditing capabilities. The audit logs are stored in the database in a separate
table and can be only inspected through the database. Currently there is no user
interface for inspecting the logs through the application itself. Audit logs
should not be exposed to regular admin users.

Additionally, this module adds system admin login for any commands run through
the console, e.g. `rails console` or `rails runner "..."`. This improves the
traceability of actions performed by system administrators through the console.
In case the regular rake tasks perform any user related actions, they are logged
as the operating system's user running those commands.

This module serves for:

1. **Compliance purposes** to improve the amount of information available for
   auditors and log new information when requested.
2. **Regulatory requirements** for some organizations.
3. **Security** when investigating or inspecting potential security breaches or
   system misuse.

## Logged events

- Login attempts (normal, system, OmniAuth, console)
- Successful logins (normal, system, OmniAuth, console)
- Failed logins (normal, system, OmniAuth, console)
- Logouts (normal, system, console)
- User record changes (create, update, and destroy)
  * Note that if the `before_` and `after_` callbacks are omitted, these changes
    are not logged, so it is suggested to add additional logging for these e.g.
    through PGAudit.

## Important note

When you install this module, you will add a new logging category as well as
personal details to be logged during the listed logged events. The logged events
are mapped to the logged in user or visitor of the website which may require
clarification in the privacy policy of the service.

The logged details include the user's IP and details about some of the user's
browser headers, such as `User-Agent`, `Sec-Ch-Ua`, `Sec-Ch-Ua-Mobile`, and
`Sec-Ch-Ua-Platform`. These details are many times categorized as identifiable
personal information, especially when these details are logged alongside each
other.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "decidim-audit"
```

And then execute:

```bash
bundle
bundle exec rails decidim_audit:install:migrations
bundle exec rails db:migrate
```

### Scheduled tasks

For production environments, add the following to the crontab in order to run
the automated tasks periodically:

```
# Cleanup old audit logs (controlled by DECIDIM_AUDIT_RETENTION_PERIOD_DAYS)
0 2 * * * cd /home/user/decidim_application && RAILS_ENV=production bundle exec rake decidim:audit:cleanup
```

### Configuration

You have the following environment variables available in order to control some
of the module's functionality:

- `DECIDIM_DOWNLOAD_YOUR_DATA_EXPIRY_TIME` - The amount of days the audit logs
  are preserved. Please note that for this to work, you have to configure the
  `decidim:audit:cleanup` rake task to run periodically.
  * Type: Integer (positive)
  * Default: `365`
  * Multitenant configurable: No

## Usage

The audit logs are collected automatically for the specified actions performed
within the system. You can inspect the logs through the database. It is also
recommended to add extra audit logging externally against the audit logs
database table (e.g. through `pgAudit`) in order to protect it against tampering
through the application itself.

The module provides the following rake task that you can use to export the audit
logs to a file:

```bash
bundle exec rails decidim:audit:export_logs
```

By default, this will export the logs to `log/RAILS_ENV_audit.log` where
`RAILS_ENV` represents the rails environment in question, e.g. `production`.
This command can be run consecutively e.g. once a day and it will automatically
detect where it left off the last time if the log file already exists. It will
only export new records to the audit log, so that the records are not duplicated
in the log file.

You can also export specific logs after a certain date/time with the following
command:

```bash
bundle exec rails decidim:audit:export_logs[2026-07-01T00:00:00Z,custom-audit.log]
```

This would export all logs that have been recorded at or after the time
`2026-07-01T00:00:00Z` to a file named `custom-audit.log`.

You can also export all logs to a custom file by leaving the first argument
empty as follows:

```bash
bundle exec rails decidim:audit:export_logs[,custom-audit.log]
```

## Contributing

See [Decidim](https://github.com/decidim/decidim).

### Testing

To run the tests run the following in the gem development path:

```bash
$ bundle
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rake test_app
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rspec
```

Note that the database user has to have rights to create and drop a database in
order to create the dummy test app database.

In case you are using [rbenv](https://github.com/rbenv/rbenv) and have the
[rbenv-vars](https://github.com/rbenv/rbenv-vars) plugin installed for it, you
can add these environment variables to the root directory of the project in a
file named `.rbenv-vars`. In this case, you can omit defining these in the
commands shown above.

### Test code coverage

If you want to generate the code coverage report for the tests, you can use
the `SIMPLECOV=1` environment variable in the rspec command as follows:

```bash
$ SIMPLECOV=1 bundle exec rspec
```

This will generate a folder named `coverage` in the project root which contains
the code coverage report.

## License

This engine is distributed under the GNU AFFERO GENERAL PUBLIC LICENSE.
