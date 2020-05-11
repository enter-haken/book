# A database gate keeper 

After [working with some entities][part2] it comes the question, how to get the data inside and outside the database.
There is no need, that other parts of an application need to now, how the data is organized in relations.
One possible way of hiding the inner database structure is to create a kind of transfer table.

```{lang=dot}
digraph {
    rankdir=LR;

    node [fontname="helvetica"];
    graph [fontname="helvetica"];
    edge [fontname="helvetica"];

    subgraph cluster_0 {
        style=filled;
        color=lightgrey;
        node [style="filled,rounded",color=white,shape=box];
        mwnode;
        label="some kind of middleware";
    }

    subgraph cluster_1 {
        style=filled;
        color=lightgrey;
        node [style="filled,rounded",color=white,shape=box];
        label="PostgreSQL";

        subgraph cluster_2 {
           style=filled;
           color=white;
           node [style="filled,rounded",color=lightgrey,shape=box];
           customer -> person;
           person -> p2p -> phone;
           person -> p2a -> address;
           label="relational\ndata";
        }
        
        mwnode -> transfer -> customer;
   }

    mwnode [ label = "middleware\nnode" ];
    transfer [ label = "transfer\ntable" ];
    person [ label = "person"];
    customer [ label = "customer" ];
    p2p [ label = "person\nto\nphone"];
    phone [ label = "phone"]
    p2a [ label = "person\nto\naddress"];
    address [ label = "address"];
}

```

This table is a kind of a gate keeper. 
Only this table should be used to communicate with he outside world.
Maybe this sounds a little bit weird for a moment, but let me show you my idea.

<!--more-->

First we have to know, which entities can be used by the middleware.

    CREATE TYPE entity AS ENUM (
        'employee',
        'customer',
        'purchase_order',
        'article',
        'price'
    );

These are [previously][part2] used examples.

    CREATE TYPE transfer_status AS ENUM (
        'pending',
        'processing',
        'succeeded',
        'succeeded_with_warning',
        'error'
    );

The requested process can have a state.

```{lang=dot}
digraph {
    rankdir=LR;

    node [fontname="helvetica",style="filled,rounded", colour=lightgrey,shape=box];
    graph [fontname="helvetica"];
    edge [fontname="helvetica"];

    subgraph cluster_0 {
        style=filled;
        color=lightgrey;
        node [style="filled,rounded",color=white,shape=box];
        pending; 
        label="request";
    }

    subgraph cluster_1 {
        style=filled;
        color=lightgrey;
        node [style="filled,rounded",color=white,shape=box];
        pending -> processing; 
        label="server\ninternal\nprocessing";
    }

    subgraph cluster_2 {
        style=filled;
        color=lightgrey;
        node [style="filled,rounded",color=white,shape=box];
        processing -> succeeded_with_warning;
        processing -> succeeded;
        processing -> error;
        label="result";
    }


    succeeded_with_warning [label = "succeded\nwith\nwarning"];
    pending;
    processing;
    succeeded;
    error; 
}
```

For the start, the transfer table has some kind of `request` and some kind of `response`.

    CREATE TABLE transfer (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        status transfer_status NOT NULL DEFAULT 'pending',
        request JSONB NOT NULL,
        result JSONB
    );

A simple insert like

    INSERT INTO transfer (request) 
        VALUES ('{"some_data" : "values"}'::JSONB);

should be enough, to communicate with the database.

Now it is time to fill this `request` object with life.
First we define some keys, which are mandatory for every request.

* The `entity` key defines the entity known to the database. (e.g. `customer` or `purchase_order`)
* The `payload` is the actual data
* The `action` key tells the database, what to do with the `payload`. Valid actions for now are `select`, `upsert` and `delete`

The trigger function is the entry point for every data access.

    CREATE FUNCTION transfer_trigger_function() RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        CASE NEW.request->>'entity'
            WHEN 'customer' THEN
                SELECT customer_manager(NEW.id, NEW.request) INTO NEW.response;
            ELSE
                RAISE EXCEPTION 'not a valid entity';
        END CASE;
        RETURN NEW;
    END
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER transfer_after_trigger BEFORE INSERT ON transfer
        FOR EACH ROW EXECUTE PROCEDURE transfer_trigger_function();

As you can see, you can access the `request` data from within the trigger function via [build in json functions][jsonFunctions].

There shouldn't be much logic in the transfer trigger. 
The entity managers should do the "hard work".

Due to this is a trigger function, you should be aware of nesting functions too much.
You should not update the `transfer` table out of the trigger function it self. 
This can lead to infinite loops.

# customer entity manager

Every entity manager should perform the `select`, `upsert` and `delete` tasks.
Let's take the `customer` as an example.

## select 

When every root entity like the `customer` relation has a `json_view` column, this should be the result for a select operation.
In the first step, the request can look like

    {
        "entity" : "customer",
        "action" : "select",
        "payload" : { 
            "id" : "29e2fa06-edfc-49ed-878b-49e8ded9bb89" 
        }
    }

The `customer_manager` checks if the action is valid and calls the assigned function.

    CREATE FUNCTION customer_manager(request JSONB) RETURNS JSONB AS $$
    DECLARE
        raw_response JSON;
    BEGIN
        CASE request->>'action'
            WHEN 'select' THEN
                SELECT customer_manager_select(request->'payload') INTO raw_response;
            ELSE
                RAISE EXCEPTION 'not a valid action';
        END CASE;
        
        RETURN raw_response;
    END
    $$ LANGUAGE plpgsql; 

The `customer_manager_select` function takes the payload and returns the `json_view` of the customer as a response.

    CREATE FUNCTION customer_manager_select(raw_payload JSONB) RETURNS JSONB AS $$
    DECLARE 
        raw_result JSONB;
    BEGIN
        SELECT json_view FROM customer WHERE id = (raw_payload->>'id')::UUID INTO raw_result;
    
        raw_result = '{ "status" : "ok", "error_code": 0 }' || jsonb_build_object('data', raw_result);
    
        RETURN raw_result;
    END
    $$ LANGUAGE plpgsql;

An

    INSERT INTO transfer (request) 
        VALUES ('{ "entity" : "customer", "action" : "select", "payload" : { "id" : "162a5041-14ba-442e-bc1b-a062b9926d49" } }'::JSONB);

will result into the following row.

                      id                  | status  |                                                request                                                |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  response                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |         created_at         |         updated_at         
    --------------------------------------+---------+-------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------+----------------------------
     874c1126-8ea6-4609-9c6d-ed52fc8bb682 | pending | {"action": "select", "entity": "customer", "payload": {"id": "162a5041-14ba-442e-bc1b-a062b9926d49"}} | {"data": {"id": "162a5041-14ba-442e-bc1b-a062b9926d49", "person": {"id": "0ec888ea-b84b-4dab-97fc-c1a6fb8ff313", "notes": null, "website": null, "addresses": [{"id": "06690a9c-92ea-4791-8922-e4e2da7f8991", "city": "Dortmund", "street": "Fakestreet", "postal_code": "44339", "address_type": "private", "house_number": "123"}, {"id": "e81b9449-7c0e-4d39-993e-e483064dd6c9", "city": "Bochum", "street": "Fakestreet", "postal_code": "44866", "address_type": "work", "house_number": "321"}], "last_name": "Hake", "birth_date": null, "first_name": "Jan Frederik", "phone_numbers": [{"id": "6c09f794-45f4-4746-ba0b-2a6ae9f8dd97", "phone_number": "+49123456789", "communication_type": "private", "communication_network": "landline", "is_primary_phone_number": true}, {"id": "5e08670f-0cf7-46b4-9c0b-40b87a727607", "phone_number": "+49151123456789", "communication_type": "private", "communication_network": "cellular_network", "is_primary_phone_number": false}], "email_addresses": [{"id": "815fe354-b157-422e-b3c3-6686fead0152", "email_address": "jan_hake@fake.de", "communication_type": "private", "is_primary_email_address": false}]}, "customer_number": "AB123456"}, "status": "ok", "error_code": 0} | 2017-07-31 10:13:46.250357 | 2017-07-31 10:13:46.250357

This is a fist shoot. 
The `response` can be quite big, so this should be refactored later.
You might also want to build a `WHERE` clause out of the `payload` (e.g. Give me all customers living in Hamburg)

## delete 

The `delete` action works with the root `id`. 

    {
        "entity" : "customer",
        "action" : "delete",
        "payload" : { 
            "id" : "29e2fa06-edfc-49ed-878b-49e8ded9bb89" 
        }
    }

The `customer_manager` must be extended for the `delete` action.

    CREATE FUNCTION customer_manager(request JSONB) RETURNS JSONB AS $$
    DECLARE
        raw_response JSON;
    BEGIN
        CASE request->>'action'
            WHEN 'select' THEN
                SELECT customer_manager_select(request->'payload') INTO raw_response;
            WHEN 'delete' THEN
                SELECT customer_manager_delete(request->'payload') INTO raw_response;
            ELSE
                RAISE EXCEPTION 'not a valid action';
        END CASE;
        
        RETURN raw_response;
    END
    $$ LANGUAGE plpgsql; 

The simplest approach would be

    CREATE FUNCTION customer_manager_delete(raw_payload JSONB) RETURNS JSONB AS $$
    DECLARE 
        raw_result JSONB;
    BEGIN
        DELETE FROM customer WHERE id = (raw_payload->>'id')::UUID;
    
        raw_result := ('{ "status" : "ok", "error_code": 0, "data" : { "id" : "' || (raw_payload->>'id') || '"}}')::JSONB;
    
        RETURN raw_result;
    END
    $$ LANGUAGE plpgsql;

This will work, if the `customer` has no reference to other tables. 
After a first `purchase_order` is created, deletion won't work any more, due to referential integrity constraints.
This is an issue, to think about.
In Germany for example, you have to store invoices for several years.
This means, customers won't be deleted, until there last invoice is deleted.
There is one approach, to set a own `deleted` property for a `customer`.
This property is very handy, so it can be included into the post [DDL][DDL] script.

    CREATE FUNCTION add_metadata_to_every_table() RETURNS VOID AS $$
    DECLARE 
        row record;
    BEGIN
        FOR row IN SELECT tablename FROM pg_tables WHERE schemaname = 'test' LOOP

            -- ...   
            EXECUTE 'ALTER TABLE ' || row.tablename || 
                ' ADD COLUMN deleted boolean NOT NULL DEFAULT false';
            -- ...
    
        END LOOP;
    END
    $$ LANGUAGE plpgsql;

Now every table has a `deleted` column.

Now the `customer_manager_select` looks like

    CREATE FUNCTION customer_manager_delete(raw_payload JSONB) RETURNS JSONB AS $$
    BEGIN
        UPDATE customer SET deleted = true WHERE id = (raw_payload->>'id')::UUID;
    
        RETURN ('{ "status" : "ok", "error_code": 0, "data" : { "id" : "' || (raw_payload->>'id') || '"}}')::JSONB;
    END
    $$ LANGUAGE plpgsql;

It might be handy, if a `deleted` record can't be updated any more.
The `metadata_trigger` is a good place for checking for the `deleted` column.

    CREATE FUNCTION metadata_trigger() RETURNS TRIGGER AS $$
    BEGIN
        IF NEW.deleted = true THEN
            RAISE EXCEPTION 'can not update the deleted record %', NEW.id::text;
        END IF;
    
        NEW.updated_at := now();
        RETURN NEW;
    END
    $$ LANGUAGE plpgsql;

## upsert

Let's start with a [known customer][customer].

    
        "person": {
            "addresses": [{
                "city": "Dortmund",
                "street": "Fakestreet",
                "postal_code": "44339",
                "address_type": "private",
                "house_number": "123"
            }, {
                "city": "Bochum",
                "street": "Fakestreet",
                "postal_code": "44866",
                "address_type": "work",
                "house_number": "321"
            }],
            "last_name": "Hake",
            "first_name": "Jan Frederik",
            "phone_numbers": [{
                "phone_number": "+49123456789",
                "communication_type": "private",
                "communication_network": "landline"
            }, {
                "phone_number": "+49151123456789",
                "communication_type": "private",
                "communication_network": "cellular_network"
            }],
            "email_addresses": [{
                "email_address": "jan_hake@fake.de",
                "communication_type": "private"
            }]
        }
    }

As you can see, there are no `id`s or `customer_numbers` present in the whole entity.
For this example, a new customer is assumed.
Imagine, you have a web form, where you enter your data. 
When you're ready with editing, this might be a result for a customer.

So we first take a look at a possible insert function.

For now, we use a simple customer number generator.

    CREATE FUNCTION customer_number() RETURNS text AS $$
        from random import randint
        return "AB%05d" % randint(0,99999)
    $$ LANGUAGE plpython3u;

The default value of the `customer_number` must be changed to

    ALTER TABLE customer ALTER COLUMN customer_number SET DEFAULT customer_number();

For a new `customer`, only `person` data is needed.
The `customer_manager` has to be extended.

    CREATE FUNCTION customer_manager(request JSONB) RETURNS JSONB AS $$
    DECLARE
        raw_response JSON;
    BEGIN
        CASE request->>'action'
           -- ...
           WHEN 'upsert' THEN
                SELECT customer_manager_upsert(request->'payload') INTO raw_response;
           -- ...  
        END CASE; 
    $$ LANGUAGE plpgsql; 

We insert this new `customer`.

    CREATE FUNCTION customer_manager_upsert(raw_payload JSONB) RETURNS JSONB AS $$
    DECLARE
        person_id UUID;
        customer_id UUID;
        result JSONB;
    BEGIN
        INSERT INTO person (first_name, last_name, birth_date, notes, website)
             VALUES (raw_payload#>>'{person,first_name}', 
                 raw_payload#>>'{person,last_name}',
                 (raw_payload#>>'{person,birth_date}')::DATE,
                 raw_payload#>>'{person,notes}',
                 raw_payload#>>'{person,website}') RETURNING id INTO person_id;
       
        INSERT INTO customer (id_person) VALUES (person_id) RETURNING id INTO customer_id;
    
        PERFORM update_json_view_customer(customer_id);
    
        SELECT json_view FROM customer WHERE id = customer_id INTO result;
    
        result = '{ "status" : "ok", "error_code": 0 }'::JSONB || jsonb_build_object('data', result);
    
        RETURN result;
    END
    $$ LANGUAGE plpgsql;

This creates a new `customer` with a new `person`.
The `update_json_view_customer` [function][customer] will update the `json_view` of the `customer`.

    {
        "id": "46624c40-c50a-478e-83e9-9117d7b87f39",
        "person": {
            "id": "81b46e11-cdef-4a71-b850-68882b474c90",
            "notes": null,
            "website": null,
            "addresses": null,
            "last_name": "Hake",
            "birth_date": null,
            "first_name": "Jan Frederik",
            "phone_numbers": null,
            "email_addresses": null
        },
        "customer_number": "AB19856"
    }

For the addresses, we have to loop through the nested json array

    IF raw_payload#>'{person}' ? 'addresses' THEN
        FOR address in SELECT * FROM jsonb_array_elements(raw_payload#>'{person,addresses}') 
        LOOP
            INSERT INTO address (street, house_number, postal_code, city)
                VALUES (address->>'street', 
                    address->>'house_number', 
                    address->>'postal_code', 
                    address->>'city')
                RETURNING id INTO address_id;

            INSERT INTO person_to_address (id_person, id_address)
                VALUES (person_id, address_id);
        END LOOP;
    END IF;

The phone numbers can be added with the following loop.

    IF raw_payload#>'{person}' ? 'phone_numbers' THEN
        FOR phone in SELECT * FROM jsonb_array_elements(raw_payload#>'{person,phone_numbers}') 
        LOOP
            INSERT INTO phone (phone_number, communication_network)
                VALUES (phone->>'phone_number', 
                    (phone->>'communication_network')::communication_network)
                RETURNING id INTO phone_id;

            INSERT INTO person_to_phone (id_person, id_phone, communication_type)
                VALUES (person_id,  phone_id, (phone->>'communication_type')::communication_type);
        END LOOP;
    END IF;

As you can see, the `communication_network` and `communication_type` have to be casted.
This is good.
Cast errors will cause an exception.
This kind of type safety will help during more complex events.

Together we have

    CREATE FUNCTION customer_manager_upsert(raw_payload JSONB) RETURNS JSONB AS $$
    DECLARE
        person_id UUID;
        customer_id UUID; 
        address_id UUID;
        phone_id UUID;
        email_id UUID;
        address JSONB;
        phone JSONB;
        email JSONB;
        result JSONB;
    BEGIN
        INSERT INTO person (first_name, last_name, birth_date, notes, website)
             VALUES (raw_payload#>>'{person,first_name}', 
                 raw_payload#>>'{person,last_name}',
                 (raw_payload#>>'{person,birth_date}')::DATE,
                 raw_payload#>>'{person,notes}',
                 raw_payload#>>'{person,website}') RETURNING id INTO person_id;
    
        IF raw_payload#>'{person}' ? 'addresses' THEN
            FOR address in SELECT * FROM jsonb_array_elements(raw_payload#>'{person,addresses}') 
            LOOP
                INSERT INTO address (street, house_number, postal_code, city)
                    VALUES (address->>'street', 
                        address->>'house_number', 
                        address->>'postal_code', 
                        address->>'city')
                    RETURNING id INTO address_id;
    
                INSERT INTO person_to_address (id_person, id_address)
                    VALUES (person_id, address_id);
            END LOOP;
        END IF;
    
        IF raw_payload#>'{person}' ? 'phone_numbers' THEN
            FOR phone in SELECT * FROM jsonb_array_elements(raw_payload#>'{person,phone_numbers}') 
            LOOP
                INSERT INTO phone (phone_number, communication_network)
                    VALUES (phone->>'phone_number', 
                        (phone->>'communication_network')::communication_network)
                    RETURNING id INTO phone_id;
    
                INSERT INTO person_to_phone (id_person, id_phone, communication_type)
                    VALUES (person_id,  phone_id, (phone->>'communication_type')::communication_type);
            END LOOP;
        END IF;
    
        IF raw_payload#>'{person}' ? 'email_addresses' THEN
            FOR email in SELECT * FROM jsonb_array_elements(raw_payload#>'{person,email_addresses}') 
            LOOP
                INSERT INTO email (email_address)
                    VALUES (email->>'email_address') 
                    RETURNING id INTO email_id;
    
                INSERT INTO person_to_email (id_person, id_email, communication_type)
                    VALUES (person_id, email_id, (email->>'communication_type')::communication_type);
            END LOOP;
        END IF;
        
        INSERT INTO customer (id_person) VALUES (person_id) RETURNING id INTO customer_id;
    
        PERFORM update_json_view_customer(customer_id);
    
        SELECT json_view FROM customer WHERE id = customer_id INTO result;
    
        result = '{ "status" : "ok", "error_code": 0 }'::JSONB || jsonb_build_object('data', result);
    
        RETURN result;
    END
    $$ LANGUAGE plpgsql;

This is a best case scenario.
There are no duplicate checks for example.
Maybe, the upsert function needs some rewrite in a more compact language like [PL/Python][plpython].

[part2]: /blog/databasearchitectureparttwo.html
[customer]: /blog/databasearchitectureparttwo.html#customer
[plpython]: https://www.postgresql.org/docs/current/static/plpython.html
[jsonFunctions]: https://www.postgresql.org/docs/current/static/functions-json.html  
[DDL]: https://en.wikipedia.org/wiki/Data_definition_language
