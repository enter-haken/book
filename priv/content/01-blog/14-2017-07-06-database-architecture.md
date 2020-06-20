# Moving ORM Mapping towards the database

Storing data in a [relational database][rdbms] has it's roots in the late sixties of the past century. 
The core idea has survived the last decades.
About 2009 the term [NoSQL][nosql] appeared.

As for now [PostgreSQL][postgresql] is the most advanced relational database in the world.
With version 9 you can store non atomic data in a JSON column. 
Document based NoSQL databases like [MongoDb][mongodb] are storing there data in so called [collections][collection].
These collections are similar to [PostgreSQL JSON columns][jsoncolumn].

With PostgreSQL you are able to use the best of both worlds.

<!--more-->

# Some tables

Before entering the JSON world, let's look at a simple example.
I use the [pgcrypto extension][pgcrypto] for generating id columns for the tables.

    CREATE EXTENSION IF NOT EXISTS pgcrypto;

For fast prototyping, you can use an own schema for the example.
    
    DROP SCHEMA IF EXISTS test CASCADE;
    CREATE SCHEMA test;
    
    SET search_path TO test,public;

If you like to store personal data you start with a `person`

    CREATE TABLE person (
        id BUD NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        first_name VARCHAR(512),
        last_name VARCHAR(512),
        birth_date DATE,
        notes VARCHAR(4096),
        website VARCHAR(256)
    );

With an `address` table,

    CREATE TABLE address (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        street VARCHAR(512), 
        house_number VARCHAR(128),
        postal_code VARCHAR(10),
        city VARCHAR(512)
    );

you can store several addresses for a person.

    CREATE TYPE address_type AS ENUM (
        'private',
        'delivery',
        'invoice',
        'work'
    );

    CREATE TABLE person_to_address(
        id_person UUID NOT NULL REFERENCES person (id),
        id_address UUID NOT NULL REFERENCES address(id),
        is_primary_address boolean NOT NULL DEFAULT false,
        address_type address_type NOT NULL DEFAULT 'private',
        PRIMARY KEY (id_person, id_address)
    );

A simple table for storing emails can look like

    CREATE TABLE email (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        eMail_address VARCHAR(256)
    );

    CREATE TYPE communication_type AS ENUM (
        'work',
        'private',
        'organization'
    );
    
    CREATE TABLE person_to_email (
        id_person UUID NOT NULL REFERENCES person (id),
        id_email UUID NOT NULL REFERENCES email (id),
        communication_type communication_type NOT NULL DEFAULT 'private',
        is_primary_email_address BOOLEAN NOT NULL DEFAULT false,
        PRIMARY KEY (id_person, id_email)
    );

Similar to an email you can store `phone data` like

    CREATE TYPE communication_network AS ENUM (
        'landline',
        'cellular_network'
    );
    
    CREATE TABLE phone (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        phone_number VARCHAR(128) NOT NULL,
        communication_network communication_network NOT NULL DEFAULT 'landline'
    );
    
    CREATE TABLE person_to_phone (
        id_person UUID NOT NULL REFERENCES person (id),
        id_phone UUID NOT NULL REFERENCES phone (id),
        communication_type communication_type NOT NULL DEFAULT 'private',
        is_primary_phone_number BOOLEAN NOT NULL DEFAULT false,
        PRIMARY KEY (id_person, id_phone)
    );

If you like to need meta data for every table, like `last update date` or `create date`, you can do this with a simple trigger function.

    CREATE FUNCTION metadata_trigger() RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at := now();
        RETURN NEW;
    END
    $$ LANGUAGE plpgsql;

In the next step, you add to every table a `created_at` and a `updated_at` column.
After this the `metadata_trigger` trigger function has to be added.
    
    CREATE FUNCTION add_metadata_to_every_table() RETURNS VOID AS $$
    DECLARE 
        row record;
    BEGIN
        FOR row IN SELECT tablename FROM pg_tables WHERE schemaname = 'test' LOOP
            EXECUTE 'ALTER TABLE ' || row.tablename || 
                ' ADD COLUMN created_at timestamp NOT NULL DEFAULT NOW();';
    
            EXECUTE 'ALTER TABLE ' || row.tablename || 
                ' ADD COLUMN updated_at timestamp NOT NULL DEFAULT NOW();';
    
            EXECUTE 'CREATE TRIGGER ' || row.tablename || '_trigger BEFORE UPDATE ON ' || row.tablename || 
                ' FOR EACH ROW EXECUTE PROCEDURE metadata_trigger();';
        END LOOP;
    END
    $$ LANGUAGE plpgsql;

No stunts so far.

Prior to the NoSQL movement, you would probably create a view for a `person`.

    CREATE VIEW person_view AS
        SELECT first_name, 
                last_name, 
                street, 
                house_number, 
                postal_code,
                city,
                email_address,
                phone_number
            FROM PERSON p
            JOIN person_to_address p2a ON p.id = p2a.id_person
            JOIN address a on p2a.id_address = a.id
            JOIN person_to_email p2e on p2e.id_person = p.id
            JOIN email e on e.id = p2e.id_email 
            JOIN person_to_phone p2p on p2p.id_person = p.id
            JOIN phone ph on ph.id = p2p.id_phone;

You get a tabular result with many redundant data here.
The next layer will take this raw data and transform it into objects.

    $ psql -U postgres -c "select * from test.person_view"
      first_name  | last_name |   street   | house_number | postal_code |   city   | address_type |  email_address   |  phone_number  
    --------------+-----------+------------+---------------+-------------+----------+--------------+------------------+----------------
     Jan Frederik | Hake      | No Street  | 3-4           | 54321       | Dortmund | work         | jan_hake@fake.de | +4923111223344
     Jan Frederik | Hake      | Fakestreet | 123           | 12345       | Dortmund | private      | jan_hake@fake.de | +4923111223344
     Jan Frederik | Hake      | No Street  | 3-4           | 54321       | Dortmund | work         | jan_hake@fake.de | +4915199887766
     Jan Frederik | Hake      | Fakestreet | 123           | 12345       | Dortmund | private      | jan_hake@fake.de | +4915199887766
    (4 rows)

It would be nice, if the database it self could provide these objects.
At this point, the JSON columns come into the game.

# JSON column

In this example the `person` table is our root relation.
We add the json column in this table.

    ALTER TABLE person ADD COLUMN json_view JSONB;
    
In the first step we create a function, that fills this column.

    CREATE FUNCTION update_json_view_person(person_id UUID) RETURNS VOID AS $$
    DECLARE
        person_raw JSONB;
    BEGIN
        SELECT row_to_json(p) FROM 
            (SELECT id, first_name, last_name, 
             birth_date, notes, website FROM person 
                WHERE id = person_id) p INTO person_raw;
        
    UPDATE person SET json_view = person_raw WHERE id = person_id;    
    END
    $$ LANGUAGE plpgsql;
    
A sample output for `json_view` can look like

    $ psql -U postgres -c "select json_view from test.person"
                                                                           json_view                                                                       
    -------------------------------------------------------------------------------------------------------------------------------------------------------
     {"id": "e881de40-596d-47f1-801c-77bf32829bfa", "notes": null, "website": null, "last_name": "Hake", "birth_date": null, "first_name": "Jan Frederik"}
    (1 row)


There are many [json functions][postgres_json_functions] available for Postgres.
The `row_to_json` function will create a json object for every result row.
In this case it is just one row.

When you want to add the address data you can use the `array_agg` [aggregate function][postgresql_aggregate_functions] to create an array from a result,

    SELECT array_to_json(array_agg(addresses)) FROM 
        (SELECT a.id, street, house_number, postal_code, city, p2a.address_type FROM address a
        JOIN person_to_address p2a ON a.id = p2a.id_address WHERE p2a.id_person = person_id) addresses 
        INTO person_addresses;

where `person_to_addresses` is a local `JSONB` variable. 
The `array_to_json` function creates a json array, which can be added to the `person_raw` with `json_build_object`.

    person_raw := person_raw 
        || jsonb_build_object('addresses', person_addresses); 

You can do this similar for `email` and `phone`.

The complete function looks like

    CREATE FUNCTION update_json_view_person(person_id UUID) RETURNS VOID AS $$
    DECLARE
        person_raw JSONB;
        person_addresses JSONB;
        person_email_addresses JSONB;
        person_phone_numbers JSONB;
    BEGIN
        SELECT row_to_json(p) FROM 
            (SELECT id, first_name, last_name, birth_date, notes, website FROM person 
                WHERE id = person_id LIMIT 1) p INTO person_raw;
        
        SELECT array_to_json(array_agg(addresses)) FROM 
            (SELECT a.id, street, house_number, postal_code, city, p2a.address_type FROM address a
            JOIN person_to_address p2a ON a.id = p2a.id_address WHERE p2a.id_person = person_id) addresses 
            INTO person_addresses;
        
        SELECT array_to_json(array_agg(email_addresses)) FROM
            (SELECT e.id, email_address, is_primary_email_address, communication_type FROM email e
                JOIN person_to_email p2e on e.id = p2e.id_email
                WHERE p2e.id_person = person_id) email_addresses INTO person_email_addresses;
     
        SELECT array_to_json(array_agg(phone_numbers)) FROM
            (SELECT p.id, phone_number, communication_type, communication_network, is_primary_phone_number FROM phone p 
                JOIN person_to_phone p2p on p.id = p2p.id_phone
                WHERE p2p.id_person = person_id) phone_numbers INTO person_phone_numbers;
        
        person_raw := person_raw 
            || jsonb_build_object('addresses', person_addresses) 
            || jsonb_build_object('email_addresses', person_email_addresses)
            || jsonb_build_object('phone_numbers', person_phone_numbers);
    
        UPDATE person SET json_view = person_raw WHERE id = person_id;    
    END
    $$ LANGUAGE plpgsql;

Now the person looks more or less complete

    $ psql -U postgres -c "select json_view from test.person" | cat
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     json_view                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     {"id": "5824be75-b444-4ac7-8d59-0763e6a6a9b3", "notes": null, "website": null, "addresses": [{"id": "41a93a1b-fd31-4f05-8a63-8921a926223c", "city": "Dortmund", "street": "Fakestreet", "postal_code": "12345", "address_type": "private", "house_number": "123"}, {"id": "4a2558c9-13b5-49a8-89b8-52022575040b", "city": "Dortmund", "street": "No Street", "postal_code": "54321", "address_type": "work", "house_number": "3-4"}], "last_name": "Hake", "birth_date": null, "first_name": "Jan Frederik", "phone_numbers": [{"id": "86941ea5-fe53-4251-bdfc-abafca40b4ab", "phone_number": "+4923111223344", "communication_type": "private", "communication_network": "landline", "is_primary_phone_number": true}, {"id": "96b8ebd3-f514-4fd7-997c-136e4a6eb270", "phone_number": "+4915199887766", "communication_type": "private", "communication_network": "cellular_network", "is_primary_phone_number": false}], "email_addresses": [{"id": "9fc2ea91-cf68-4624-a903-381d765be25c", "email_address": "jan_hake@fake.de", "communication_type": "private", "is_primary_email_address": false}]}
    (1 row)

With a little bit formatting you get.

    {
        "id": "5824be75-b444-4ac7-8d59-0763e6a6a9b3",
        "notes": null,
        "website": null,
        "addresses": [{
            "id": "41a93a1b-fd31-4f05-8a63-8921a926223c",
            "city": "Dortmund",
            "street": "Fakestreet",
            "postal_code": "12345",
            "address_type": "private",
            "house_number": "123"
        }, {
            "id": "4a2558c9-13b5-49a8-89b8-52022575040b",
            "city": "Dortmund",
            "street": "No Street",
            "postal_code": "54321",
            "address_type": "work",
            "house_number": "3-4"
        }],
        "last_name": "Hake",
        "birth_date": null,
        "first_name": "Jan Frederik",
        "phone_numbers": [{
            "id": "86941ea5-fe53-4251-bdfc-abafca40b4ab",
            "phone_number": "+4923111223344",
            "communication_type": "private",
            "communication_network": "landline",
            "is_primary_phone_number": true
        }, {
            "id": "96b8ebd3-f514-4fd7-997c-136e4a6eb270",
            "phone_number": "+4915199887766",
            "communication_type": "private",
            "communication_network": "cellular_network",
            "is_primary_phone_number": false
        }],
        "email_addresses": [{
            "id": "9fc2ea91-cf68-4624-a903-381d765be25c",
            "email_address": "jan_hake@fake.de",
            "communication_type": "private",
            "is_primary_email_address": false
        }]
    }

Every time the `update_json_view_person` function is called, the `json_view` column is updated with the current relational data.

In the [next part](/blog/databasearchitectureparttwo.html), I take a look at some other use cases.

[rdbms]: https://en.wikipedia.org/wiki/Relational_database
[nosql]: https://en.wikipedia.org/wiki/NoSQL
[postgresql]: https://www.postgresql.org/ 
[collection]: https://docs.mongodb.com/v3.2/core/databases-and-collections/
[mongodb]: https://www.mongodb.com/
[jsoncolumn]: https://www.postgresql.org/docs/9.6/static/datatype-json.html
[pgcrypto]: https://www.postgresql.org/docs/current/static/pgcrypto.html
[postgres_json_functions]: https://www.postgresql.org/docs/9.3/static/functions-json.html
[postgresql_aggregate_functions]: https://www.postgresql.org/docs/current/static/functions-aggregate.html
