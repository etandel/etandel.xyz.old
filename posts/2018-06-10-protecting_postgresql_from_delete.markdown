---
title: Como impedir deleções em uma tabela no postgres
---

- Can't create trigger "INSTEAD OF" for tables, so we must use RULES;
- Rules only allow for doing INSERT, UPDATE, DELETE, SELECT;
- Hence, the strategy is: create a function that raises an error, call it from the select of a rule

Final solution:
```sql
CREATE FUNCTION backend_customer_protect_delete() RETURNS int as $backend_customer_protect_delete$
    BEGIN
        RAISE EXCEPTION 'Deleting customer is not allowed!!11!';
        RETURN 1;
    END;
$backend_customer_protect_delete$ LANGUAGE plpgsql;


CREATE OR REPLACE RULE backend_customer_protect_delete
    AS ON DELETE
    TO backend_customer
    DO INSTEAD SELECT backend_customer_protect_delete();
```
