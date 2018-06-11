---
title: Impedindo deleções em uma tabela no Postgres
---


Suponha que alguns dados estão sumindo do seu banco, e aparentemente nada no código da aplicação parece deletar explicitamente esses dados. Será que é alguma operação interna do seu framework ou ORM que está sendo executada? Será que é algum microsserviço que está se comportando mal? Será que é algum `CASCADE` que não devia acontecer?

Na [Onyo](https://www.site.onyo.com/) tivemos esse exato problema um tempo atrás, em que certos dados estavam sumindo sem razão aparente. Para resolver, precisávamos de uma solução que pudesse não só impedir qualquer `DELETE` na tabela, mas também identificar a parte da aplicação que estava causando esse comportamento.

Como não sabíamos qual a origem do problema, só poderíamos resolver isso a nível do banco de dados, e para isso a solução mais óbvia pareceu ser usar triggers.

### Triggers

Gatilhos ou triggers permitem atrelar certos procedimentos a certos eventos no banco de dados.
Por exemplo, suponha que você queira salvar um histórico de todas as alterações de preço na sua tabela de produtos. Uma forma de fazer isso é criar uma tabela de histórico e um trigger que faça `INSERT` do histórico sempre que ocorrer um `UPDATE` de produto:

```sql
CREATE TABLE product (
  id SERIAL PRIMARY KEY,
  price NUMERIC(6, 2) NOT NULL
);

CREATE TABLE product_price_history (
  product_id INTEGER NOT NULL REFERENCES product(id) ON DELETE CASCADE,
  update_datetime TIMESTAMP NOT NULL,
  old_price NUMERIC(6, 2) NOT NULL,
  new_price NUMERIC(6, 2) NOT NULL
);

CREATE OR REPLACE FUNCTION process_product_price_change() RETURNS trigger AS $log_product_price_change$
    BEGIN
        INSERT INTO product_price_history SELECT OLD.id, now(), OLD.price, NEW.price;
        RETURN NEW;
    END;
$log_product_price_change$ LANGUAGE plpgsql;


CREATE TRIGGER log_product_price_change
    AFTER UPDATE ON product
    FOR EACH ROW
    EXECUTE PROCEDURE process_product_price_change()
;
```

Note que definimos não só o tipo do evento, mas também em que momento o trigger deve ser executado. Entre as possiblidades está executar o procedimento *em vez* do evento original. Usando o exemplo acima, poderíamos então evitar deleções de produtos dessa forma:

```sql
CREATE FUNCTION product_protect_delete() RETURNS trigger as $product_protect_delete$
    BEGIN
        RAISE EXCEPTION 'Nope nope nope';
        RETURN NULL;
    END;
$product_protect_delete$ LANGUAGE plpgsql;

CREATE TRIGGER block_product_deletion
    INSTEAD OF DELETE ON product
    EXECUTE PROCEDURE product_protect_delete()
;
```

Essa solução parece resolver nosso problema: em vez de deletar o produto, a consulta vai levantar um erro na nossa aplicação e assim poderemos descobrir qual parte do código está fazendo besteira. Ela só tem um problema: quando tentamos executar as definições acima, recebemos o erro:

```
ERROR:  "product" is a table
DETAIL:  Tables cannot have INSTEAD OF triggers.
```

Esse erro ocorre porque triggers com `INSTEAD OF` só são permitidos para views, não para tabelas. O que fazer então?


### Solução 1 - trigger BEFORE DELETE + retornar NULL na função

A [documentação do PostgreSQL](https://www.postgresql.org/docs/10/static/plpgsql-trigger.html) diz que triggers que acontecem antes do evento podem retornar `NULL` para sinalizar que as operações seguintes, incluindo o próprio evento e outros triggers, devem ser abortadas. Com isso, podemos manter exatamente a mesma função e mudar apenas a definição do trigger:

```sql
CREATE FUNCTION product_protect_delete() RETURNS trigger as $product_protect_delete$
    BEGIN
        RAISE EXCEPTION 'Nope nope nope';
        RETURN NULL;
    END;
$product_protect_delete$ LANGUAGE plpgsql;

CREATE TRIGGER block_product_deletion
    BEFORE DELETE ON product
    EXECUTE PROCEDURE product_protect_delete()
;
```

### Solução 2 - usar rules em vez de triggers

O PostgreSQL também oferece o mecanismo de rules, que são parecidas com triggers, mas bem mais poderosas. Enquanto triggers são chamados *enquanto* a query original já está sendo executada, rules permitem _reescrever_ a query *antes* de ela ser executada. Isso significa que podemos impedir as deleções simplesmente refazendo a query original para lançar um erro:

```sql
CREATE FUNCTION product_protect_delete() RETURNS int as $product_protect_delete$
    BEGIN
        RAISE EXCEPTION 'Nope nope nope';
        RETURN 1;
    END;
$product_protect_delete$ LANGUAGE plpgsql;


CREATE RULE block_product_deletion
    AS ON DELETE
    TO product
    DO INSTEAD SELECT product_protect_delete()
;
```

Essa solução também funciona, e tem a vantagem de explicitar na definição que o delete está sendo substituído por outra query, em vez de impedir a deleção implicitamente fazendo a função retornar `NULL` como na opção anterior. No entanto, a mensagem de erro fica bem menos clara quando a origem da deleção vem de um `CASCADE`, dando um erro de integridade em vez do 'Nope nope nope' definido. A escolha entre as duas soluções é subjetiva, e eu pessoalmente prefiro a primeira solução para ter a consistência da mensagem de erro.


### Conclusão

No caso da Onyo usamos a segunda opção simplesmente porque eu desconhecia a primeira na época. Mesmo assim, conseguimos aplicar essa solução e resolver o problema. A causa? Uma certa funcionalidade esquecida executava uma requisição de DELETE em nossa API RESTful, fazendo com que o [Django Rest Framework](http://www.django-rest-framework.org/) prontamente deletasse o recurso no banco.

Eu não recomendo usar triggers ou rules para implementar regras de negócio, pois misturar a lógica entre código e banco pode dificultar bastante a manutenção da aplicação, por motivos que que fogem ao escopo desse post. No entanto, essas ferramentas podem ser a última barreira para proteger a integridade dos seus dados e ainda funcionam como uma ótima forma de [debug de guerrilha](https://www.youtube.com/watch?v=bAcfPzxB3dk).

