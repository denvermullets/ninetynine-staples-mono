solidqueue loads schema first instead of migrations so you need to run:

`rails db:prepare` before running migrate or else it'll wipe the schema file for the queue
`rails db:rollback:primary`
`rails db:migrate:primary`

`bin/jobs` to run solidqueue, locally
