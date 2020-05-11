# Working with immutable data in Postgres

After taking a [first look][dbArchitecturePart1] at the JSON columns, let's look at a few possible applications.
Imagine a simple shop system with articles, prices and purchase orders.

An article can be `active` or `inactive`.

    CREATE TYPE article_status AS ENUM (
        'active',
        'inactive'
    );

Every article has an `article_number`.

    CREATE TABLE article (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        article_number VARCHAR(128) UNIQE NOT NULL DEFAULT '',
        name VARCHAR(128),
        description VARCHAR(2048),
        status article_status NOT NULL DEFAULT 'active'
    );

You can see that `id` and `article_number` are unique, so both could be used as a primary key.
This is not normalized in a usual way. 

There are a few points, why to stick to this solution.

<!--more-->

* A primary key should only be used to identify a record.
Not more, not less.
* There must be no reuse for a business case, like it would be for `article_number`.
The `article_number` could not be changed so easily, after being promoted to a primary key.
* A `article_number` identifies an article entity not a database record.

# prices with history

Every `article` can have a price.

    CREATE TABLE price (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        id_article UUID NOT NULL REFERENCES article(id),
        price real NOT NULL DEFAULT 0.0,
        scale_lower_limit INT NOT NULL DEFAULT 1,
        scale_upper_limit INT NOT NULL DEFAULT 2147483647,
        valid_from DATE NOT NULL DEFAULT current_date,
        valid_to DATE NOT NULL DEFAULT current_date + interval '1 year'
    );

An `article` can have multiple prices over time. 
There can be multiple price scales.
A `price` will be more likely changed than an `article`.
Price changes may be interesting for reporting issues.

You can store these changes in a JSONB column.

    ALTER TABLE price ADD COLUMN history JSONB;

Every time, a price record changes. these changes should be saved. 
These saved items should be immutable over time.

    CREATE FUNCTION history_trigger() RETURNS TRIGGER AS $$.
    
    BEGIN
        IF NEW.history IS NULL THEN
            NEW.history := '[]'::JSONB;
        END IF;
    
        NEW.history := NEW.history::JSONB || (row_to_json(OLD)::JSONB - 'history');
        RETURN NEW;
    END
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER price_history_trigger BEFORE UPDATE ON price
        FOR EACH ROW EXECUTE PROCEDURE history_trigger();

First of all, an `article` has to be created.

    $ psql -U postgres -c "INSERT INTO test.article (article_number, name, description) \
    > VALUES ('AB12345', 'Test article','Test desc')"
    INSERT 0 1

For this newly inserted article

    $ psql -U postgres -c "SELECT * from test.article" | cat
                      id                  | article_number |     name     | description | status |         created_at         |         updated_at         
    --------------------------------------+----------------+--------------+-------------+--------+----------------------------+----------------------------
     f12def37-3de6-4985-8912-054891631499 | AB12345        | Test article | Test desc   | active | 2017-07-15 19:17:14.727931 | 2017-07-15 19:17:14.727931
    (1 row)

you can add a `price`,

    $ psql -U postgres -c "INSERT INTO test.price (id_article, price) \
    > VALUES ('f12def37-3de6-4985-8912-054891631499',50.5)"
    INSERT 0 1

    $ psql -U postgres -c "SELECT * FROM test.price" | cat
                      id                  |              id_article              | price | scale_lower_limit | scale_upper_limit | valid_from |  valid_to  | history |         created_at         |         updated_at         
    --------------------------------------+--------------------------------------+-------+-------------------+-------------------+------------+------------+---------+----------------------------+----------------------------
     3a113796-05fd-4ff3-a33f-b08f92c01cd8 | f12def37-3de6-4985-8912-054891631499 |  50.5 |                 1 |        2147483647 | 2017-07-15 | 2018-07-15 |         | 2017-07-15 19:21:39.245331 | 2017-07-15 19:21:39.245331
    (1 row)

and raise the price value for the `price` record.

    $ psql -U postgres -c "UPDATE test.price SET price = 70.2 WHERE id = '3a113796-05fd-4ff3-a33f-b08f92c01cd8'"
    UPDATE 1

    $ psql -U postgres -c "SELECT * FROM test.price" | cat
                      id                  |              id_article              | price | scale_lower_limit | scale_upper_limit | valid_from |  valid_to  |                                                                                                                                                           history                                                                                                                                                            |         created_at         |         updated_at
    --------------------------------------+--------------------------------------+-------+-------------------+-------------------+------------+------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------+----------------------------
     3a113796-05fd-4ff3-a33f-b08f92c01cd8 | f12def37-3de6-4985-8912-054891631499 |  70.2 |                 1 |        2147483647 | 2017-07-15 | 2018-07-15 | [{"id": "3a113796-05fd-4ff3-a33f-b08f92c01cd8", "price": 50.5, "valid_to": "2018-07-15", "created_at": "2017-07-15T19:21:39.245331", "id_article": "f12def37-3de6-4985-8912-054891631499", "updated_at": "2017-07-15T19:21:39.245331", "valid_from": "2017-07-15", "scale_lower_limit": 1, "scale_upper_limit": 2147483647}] | 2017-07-15 19:21:39.245331 | 2017-07-15 19:25:04.672829
    (1 row)

The `history` is updated every time, a `price` record is updated.

# customer

A `customer` is a kind of `person` which has a `customer_number`

    CREATE TABLE customer (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        id_person UUID NOT NULL REFERENCES person(id),
        customer_number VARCHAR(128) NOT NULL DEFAULT '',
        json_view JSONB
    );

As you can see, a `json_view` column is added to the `customer`.
The only difference between a `person` and a customer is the `customer_number`.

Analog to the `persons` [update function][personUpdateFunction] we can write an update function for a `customer`
    
    CREATE FUNCTION update_json_view_customer(id_customer UUID) RETURNS VOID AS $$
    DECLARE
        customer_raw JSONB;
        person_id UUID;
    BEGIN
    
        IF NOT EXISTS (SELECT 1 FROM person p 
            JOIN customer c on p.id = c.id_person 
            WHERE p.json_view IS NOT NULL AND c.id = id_customer) THEN
    
            SELECT id_person FROM customer WHERE id = id_customer INTO person_id;
    
            RAISE NOTICE 'update json_view for person %', person_id;
    
            perform update_json_view_person(person_id);
        END IF;
    
        SELECT row_to_json(c) FROM 
            (SELECT c.id, customer_number, p.json_view AS person_json_view FROM customer c
                JOIN person p on c.id_person = p.id
                WHERE c.id = id_customer LIMIT 1) c INTO customer_raw;
    
        customer_raw := customer_raw || jsonb_build_object('person', customer_raw->'person_json_view');
        customer_raw := customer_raw - 'person_json_view';
    
        UPDATE customer SET json_view = customer_raw WHERE id = id_customer;
    END
    $$ LANGUAGE plpgsql;

The `json_view` of the `person` is reused.

Let's take a inserted person.

    $ psql -U postgres -c "SELECT id FROM test.person"
                      id
    --------------------------------------
     da44de2f-aa0a-43c5-9fed-dcbb5b6c32a2
    (1 row)

and insert a new `customer` for this `person`.

    $ psql -U postgres -c "INSERT INTO test.customer (customer_number, id_person) \
    VALUES ('AB12345', 'da44de2f-aa0a-43c5-9fed-dcbb5b6c32a2');"
    INSERT 0 1

The newly inserted `customer` looks like

    $ psql -U postgres -c "SELECT * FROM test.customer" | cat
                      id                  |              id_person               | customer_number | json_view |         created_at         |         updated_at         
    --------------------------------------+--------------------------------------+-----------------+-----------+----------------------------+----------------------------
     88a99ea7-4281-496b-9c95-3625101177ca | da44de2f-aa0a-43c5-9fed-dcbb5b6c32a2 | AB12345         |           | 2017-07-15 18:41:27.811324 | 2017-07-15 18:41:27.811324
    (1 row)

Now the `customer`'s `json_view` must be filled.

    $ psql -U postgres -c "SET search_path TO test,public; \
    >  SELECT test.update_json_view_customer('88a99ea7-4281-496b-9c95-3625101177ca');"
     update_json_view_customer 
    ---------------------------
      
    (1 row)

    $ psql -U postgres -c "SELECT * FROM test.customer" | cat
                      id                  |              id_person               | customer_number |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              json_view                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |         created_at         |         updated_at         
    --------------------------------------+--------------------------------------+-----------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------+----------------------------
     88a99ea7-4281-496b-9c95-3625101177ca | da44de2f-aa0a-43c5-9fed-dcbb5b6c32a2 | AB12345         | {"id": "88a99ea7-4281-496b-9c95-3625101177ca", "person": {"id": "da44de2f-aa0a-43c5-9fed-dcbb5b6c32a2", "notes": null, "website": null, "addresses": [{"id": "9a78ceb0-5169-4bca-bbf5-aac54fcaa95a", "city": "Dortmund", "street": "Fakestreet", "postal_code": "44339", "address_type": "private", "house_number": "123"}, {"id": "c69ec275-0a05-42ce-80ea-1ea1b5bcbd78", "city": "Bochum", "street": "Fakeroad", "postal_code": "44866", "address_type": "work", "house_number": "321"}], "last_name": "Hake", "birth_date": null, "first_name": "Jan Frederik", "phone_numbers": [{"id": "0df74379-6512-4f54-a1a7-fee1c1605342", "phone_number": "+49231123456789", "communication_type": "private", "communication_network": "landline", "is_primary_phone_number": true}, {"id": "a9d36784-7af3-47e8-b357-2f03500f7d66", "phone_number": "+49151123456789", "communication_type": "private", "communication_network": "cellular_network", "is_primary_phone_number": false}], "email_addresses": [{"id": "ff2fee9e-490f-49b2-8e0e-69d5bddd2ca0", "email_address": "jan_hake@fake.de", "communication_type": "private", "is_primary_email_address": false}]}, "customer_number": "AB12345"} | 2017-07-15 18:41:27.811324 | 2017-07-15 18:50:47.591534
    (1 row)

a little bit more beautifull

    {
        "id": "88a99ea7-4281-496b-9c95-3625101177ca",
        "person": {
            "id": "da44de2f-aa0a-43c5-9fed-dcbb5b6c32a2",
            "notes": null,
            "website": null,
            "addresses": [{
                "id": "9a78ceb0-5169-4bca-bbf5-aac54fcaa95a",
                "city": "Dortmund",
                "street": "Fakestreet",
                "postal_code": "44339",
                "address_type": "private",
                "house_number": "123"
            }, {
                "id": "c69ec275-0a05-42ce-80ea-1ea1b5bcbd78",
                "city": "Bochum",
                "street": "Fakeroad",
                "postal_code": "44866",
                "address_type": "work",
                "house_number": "321"
            }],
            "last_name": "Hake",
            "birth_date": null,
            "first_name": "Jan Frederik",
            "phone_numbers": [{
                "id": "0df74379-6512-4f54-a1a7-fee1c1605342",
                "phone_number": "+49231123456789",
                "communication_type": "private",
                "communication_network": "landline",
                "is_primary_phone_number": true
            }, {
                "id": "a9d36784-7af3-47e8-b357-2f03500f7d66",
                "phone_number": "+49151123456789",
                "communication_type": "private",
                "communication_network": "cellular_network",
                "is_primary_phone_number": false
            }],
            "email_addresses": [{
                "id": "ff2fee9e-490f-49b2-8e0e-69d5bddd2ca0",
                "email_address": "jan_hake@fake.de",
                "communication_type": "private",
                "is_primary_email_address": false
            }]
        },
        "customer_number": "AB12345"
    }

# a purchase process 

Now we have a `customer` and `articles` with `prices`.
The next step is to buy something. 
But first we take a look at a common workflow, when you buy something in a shop.

```{lang="dot"}
digraph { 
    rankdir="LR";   

    node [fontname="helvetica"];
    graph [fontname="helvetica"];
    edge [fontname="helvetica"];
    
    subgraph cluster_0 {
        style=filled;
        color=lightgrey;
		node [style="filled,rounded",color=white,shape=box];
	    po -> rts;	
        po -> item [label="add"];
        po -> item [label="modify"];
        po -> item  [label="remove"];
	    label = "mutable\ndata";
	} 
 
    subgraph cluster_1 {
        style=filled;
        color=lightgrey;
		node [style="filled,rounded",color=white,shape=box];
	    rts -> snd -> delivered -> rfi -> inv; 	
        item -> snd [label="frozen\npurchase\norder\nitems"];
		label = "immutable\ndata";
	} 


    start [ label="start", shape=Mdiamond];
    end [ label="end", shape="Msquare"];
 
    delivered [ label="delivered"];
    po [ label="purchase\norder"];
    rts [ label="ready to\nsend"];
    rfi [ label="ready for\ninvoice"];
    inv [ label="invoiced"];
    snd [ label="send"];
    item [ label="items"];
 
    start -> po;
    inv -> end;
}
```

When you enter a web shop, you can search for articles, and put them into a shopping cart.
While you are creating your cart, you can change the amount of an article, or delete previously added ones.
When you are satisfied with your selection, you finalize your requisition.
After finalization, parts of your cart like the items can not be changed any more.

Article descriptions or names can be changed over time. 
Prices may vary.

## a purchase order 

A purchase order can have one of the following states

    CREATE TYPE purchase_order_status AS ENUM (
        'requisition', 
        'ready_to_send', 
        'send', 
        'delivered',
        'ready_for_invoice',
        'invoiced',
        'finalized');

It is assumed, that every purchase order has a relation to a `customer`.
For this example this is enough.


    CREATE TABLE purchase_order (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        id_customer UUID NOT NULL REFERENCES customer(id),
        purchase_order_number VARCHAR(128) NOT NULL UNIQUE DEFAULT '',
        status purchase_order_status NOT NULL DEFAULT 'requisition'
    );

Every purchase order has a unique `purchase_order_number`.

    CREATE TABLE purchase_order_item (
        id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        id_purchase_order UUID NOT NULL REFERENCES purchase_order(id),
        id_article UUID NOT NULL REFERENCES article(id),
        id_price UUID NOT NULL REFERENCES price(id),
        amount int NOT NULL DEFAULT 1
    );

A `purchase_order_item` has a reference to a `purchase_order`.

Unless we are in a mutable state, There is no need for storing extra data.
This changes, when the `purchase_order_status` changes to `send`.
The `purchase_order_items`  can't be changed any more.
The purchased items are on their way to the `customer`.
The only thing, which can change is the `purchase_order_status`, but only forward in the chain.

This is the point, where the items should be saved in a immutable way.
There are no immutable types in Postgres, but it can be made hard for a process to change such data columns, which should not be updated.

For our example, we must store the article, with it's price at the time of purchase.
We also need the `customer`, who must have some kind of address, to send the delivery to.


    ALTER TABLE purchase_order ADD COLUMN frozen_purchase_order JSONB;

This column should be updated, when the `purchase_order_status` is set to `send`.
So, we need a trigger function which listens on state changes.
The scaffold looks like

    CREATE FUNCTION freeze_purchase_order() RETURNS TRIGGER AS $$
    BEGIN
        return NEW;
    END
    $$ LANGUAGE plpgsql;
    
    CREATE TRIGGER freeze_purchase_order_trigger BEFORE UPDATE ON purchase_order
        FOR EACH ROW EXECUTE PROCEDURE freeze_purchase_order();

Now we listen to the `send` state.
At this point, the purchase order some data have to be frozen.
Everything below this state can be ignored.

    IF NEW.status = ANY('{requisition,ready_to_send}'::purchase_order_status[]) THEN
        RAISE NOTICE 'nothing to do';
        RETURN NEW;
    END IF;
 
To store some JSON objects we define some variables

    DECLARE
        frozen_purchase_order JSONB;
        customer JSONB;
        purchase_order_items JSONB;
        rawItem RECORD;

The `frozen_purchase_order` will be the result JSON. 
First we get the current `customer`

    SELECT json_view FROM customer WHERE id = NEW.id_customer INTO customer;

A purchase order item contains an article and a price. 
The function to get a json representation for a item can look like

    CREATE FUNCTION get_json_from_item(item_id UUID) RETURNS JSONB AS $$
    DECLARE
        result JSONB;
        article JSONB;
        price JSONB;
    BEGIN
        SELECT row_to_json(item) FROM (SELECT id_article, id_price, amount FROM purchase_order_item WHERE id = item_id) item INTO result; 
        SELECT row_to_json(rawArticle) FROM (SELECT id, article_number, name, description FROM article WHERE id = (result->>'id_article')::UUID) rawArticle INTO article;
        SELECT row_to_json(rawPrice) FROM (SELECT id, p.price, scale_lower_limit, scale_upper_limit, valid_from, valid_to FROM price p WHERE id = (result->>'id_price')::UUID) rawPrice INTO price;
    
        result := result 
         || jsonb_build_object('article', article)
         || jsonb_build_object('price', price);
    
        result := result - 'id_article';
        result := result - 'id_price';
    
        RETURN result;
    END
    $$ LANGUAGE plpgsql;

The purchase order trigger function can consume this function as following

    purchase_order_items := '[]'::JSONB;

    FOR rawItem IN (SELECT get_json_from_item(id)::JSONB AS get_json FROM purchase_order_item WHERE id_purchase_order = NEW.id) 
    LOOP
        purchase_order_items := purchase_order_items || rawItem.get_json;    
    END LOOP;

The current NEW record must be set as root for our result JSON.

    SELECT row_to_json(NEW.*) INTO frozen_purchase_order;

Then the `customer` and the `items` have to be merged into the result.

    frozen_purchase_order := frozen_purchase_order 
        || jsonb_build_object('items', purchase_order_items)
        || jsonb_build_object('customer', customer);

At last, some unnecessary fields must be deleted from our frozen purchase order.

    frozen_purchase_order := frozen_purchase_order - 'frozen_purchase_order';
    frozen_purchase_order := frozen_purchase_order - 'id_customer';

Then we have our result.

    NEW.frozen_purchase_order := frozen_purchase_order;
 
The complete function looks like

    CREATE FUNCTION freeze_purchase_order() RETURNS TRIGGER AS $$
    DECLARE
        frozen_purchase_order JSONB;
        customer JSONB;
        purchase_order_items JSONB;
        rawItem RECORD;
    BEGIN
        IF NEW.status = ANY('{requisition,ready_to_send}'::purchase_order_status[]) THEN
            RAISE NOTICE 'nothing to do';
            RETURN NEW;
        END IF;
        RAISE NOTICE 'freeze';
    
        SELECT json_view FROM customer WHERE id = NEW.id_customer INTO customer;
    
        purchase_order_items := '[]'::JSONB;
    
        FOR rawItem IN (SELECT get_json_from_item(id)::JSONB AS get_json FROM purchase_order_item WHERE id_purchase_order = NEW.id) 
        LOOP
            purchase_order_items := purchase_order_items || rawItem.get_json;    
        END LOOP;
    
        SELECT row_to_json(NEW.*) INTO frozen_purchase_order;
    
        frozen_purchase_order := frozen_purchase_order 
            || jsonb_build_object('items', purchase_order_items)
            || jsonb_build_object('customer', customer);
    
        frozen_purchase_order := frozen_purchase_order - 'frozen_purchase_order';
        frozen_purchase_order := frozen_purchase_order - 'id_customer';
    
        NEW.frozen_purchase_order := frozen_purchase_order;
        
        RETURN NEW;
    END
    $$ LANGUAGE plpgsql;

## add some data

    $ psql -U postgres -c "SELECT id FROM test.customer"
                      id
    --------------------------------------
     7a24ed2c-c873-4fdf-91cf-3574410acc49
    (1 row)

    $ psql -U postgres -c "INSERT INTO test.purchase_order (id_customer, purchase_order_number) \
    > VALUES ('7a24ed2c-c873-4fdf-91cf-3574410acc49', 'PO12345');"
    INSERT 0 1

    $ psql -U postgres -c "SELECT * FROM test.purchase_order;"
                      id                  |             id_customer              | purchase_order_number |   status    | frozen_purchase_order |        created_at         |        updated_at         
    --------------------------------------+--------------------------------------+-----------------------+-------------+-----------------------+---------------------------+---------------------------
     29e2fa06-edfc-49ed-878b-49e8ded9bb89 | 7a24ed2c-c873-4fdf-91cf-3574410acc49 | PO12345               | requisition |                       | 2017-07-16 21:15:41.81893 | 2017-07-16 21:15:41.81893
    (1 row)

Now we add our `article` with our `price`.

    $ psql -U postgres -c "SELECT * FROM test.article"
                      id                  | article_number |     name     | description | status |         created_at         |         updated_at         
    --------------------------------------+----------------+--------------+-------------+--------+----------------------------+----------------------------
     0b177d42-368a-4cfa-bf8d-e863f4e8a1bd | AB12345        | Test article | Test desc   | active | 2017-07-16 21:06:03.668307 | 2017-07-16 21:06:03.668307
    (1 row)
    
    $ psql -U postgres -c "SELECT * FROM test.price;"
                      id                  |              id_article              | price | scale_lower_limit | scale_upper_limit | valid_from |  valid_to  | history |         created_at         |         updated_at         
    --------------------------------------+--------------------------------------+-------+-------------------+-------------------+------------+------------+---------+----------------------------+----------------------------
     ac73b43d-e5ef-46dd-81e9-94291aa669c7 | 0b177d42-368a-4cfa-bf8d-e863f4e8a1bd |  50.5 |                 1 |        2147483647 | 2017-07-16 | 2018-07-16 |         | 2017-07-16 21:06:03.668307 | 2017-07-16 21:06:03.668307
    (1 row)
    
    $ psql -U postgres -c "INSERT INTO test.purchase_order_item (id_purchase_order, id_article, id_price) \
    > VALUES ('29e2fa06-edfc-49ed-878b-49e8ded9bb89', '0b177d42-368a-4cfa-bf8d-e863f4e8a1bd', 'ac73b43d-e5ef-46dd-81e9-94291aa669c7')"
    INSERT 0 1

Changing the state to `ready_to_send` will result

    $ psql -U postgres -c "SET search_path TO test,public; UPDATE purchase_order SET status = 'ready_to_send' \ 
    > WHERE id = '29e2fa06-edfc-49ed-878b-49e8ded9bb89'"
    NOTICE:  nothing to do
    UPDATE 1

Now we set the state to 'send'

    $ psql -U postgres -c "SET search_path TO test,public; UPDATE purchase_order SET status = 'send' \
    > WHERE id = '29e2fa06-edfc-49ed-878b-49e8ded9bb89'"
    NOTICE:  freeze
    UPDATE 1

    $ psql -U postgres -c "SELECT * from test.purchase_order" | cat
                      id                  |             id_customer              | purchase_order_number | status |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  frozen_purchase_order                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |        created_at         |        updated_at         
    --------------------------------------+--------------------------------------+-----------------------+--------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+---------------------------+---------------------------
     29e2fa06-edfc-49ed-878b-49e8ded9bb89 | 7a24ed2c-c873-4fdf-91cf-3574410acc49 | PO12345               | send   | {"id": "29e2fa06-edfc-49ed-878b-49e8ded9bb89", "items": [{"price": {"id": "ac73b43d-e5ef-46dd-81e9-94291aa669c7", "price": 50.5, "valid_to": "2018-07-16", "valid_from": "2017-07-16", "scale_lower_limit": 1, "scale_upper_limit": 2147483647}, "amount": 1, "article": {"id": "0b177d42-368a-4cfa-bf8d-e863f4e8a1bd", "name": "Test article", "description": "Test desc", "article_number": "AB12345"}}], "status": "send", "changes": null, "customer": {"id": "7a24ed2c-c873-4fdf-91cf-3574410acc49", "person": {"id": "35b40b2f-bf40-4f71-8319-f7757de3e1f4", "notes": null, "website": null, "addresses": [{"id": "7a7f1e44-f6a6-495e-893b-e5806289ea81", "city": "Dortmund", "street": "Fakestreet", "postal_code": "44339", "address_type": "private", "house_number": "123"}, {"id": "1d8c41e5-bcd6-4842-864d-62c4da2fc506", "city": "Bochum", "street": "Fakestreet", "postal_code": "44866", "address_type": "work", "house_number": "321"}], "last_name": "Hake", "birth_date": null, "first_name": "Jan Frederik", "phone_numbers": [{"id": "618d19d6-3daf-4029-8d0f-1535272ec212", "phone_number": "+49123456789", "communication_type": "private", "communication_network": "landline", "is_primary_phone_number": true}, {"id": "81403e1d-1055-4953-8b1a-fcca9d034b1b", "phone_number": "+49151123456789", "communication_type": "private", "communication_network": "cellular_network", "is_primary_phone_number": false}], "email_addresses": [{"id": "a2f79f62-a497-4bdb-8f1b-03d6b7aacb30", "email_address": "jan_hake@fake.de", "communication_type": "private", "is_primary_email_address": false}]}, "customer_number": "AB123456"}, "created_at": "2017-07-16T21:15:41.81893", "updated_at": "2017-07-16T21:25:03.02978", "purchase_order_number": "PO12345"} | 2017-07-16 21:15:41.81893 | 2017-07-16 21:26:44.87835
    (1 row)

The frozen purchase order looks like


    {
        "id": "29e2fa06-edfc-49ed-878b-49e8ded9bb89",
        "items": [{
            "price": {
                "id": "ac73b43d-e5ef-46dd-81e9-94291aa669c7",
                "price": 50.5,
                "valid_to": "2018-07-16",
                "valid_from": "2017-07-16",
                "scale_lower_limit": 1,
                "scale_upper_limit": 2147483647
            },
            "amount": 1,
            "article": {
                "id": "0b177d42-368a-4cfa-bf8d-e863f4e8a1bd",
                "name": "Test article",
                "description": "Test desc",
                "article_number": "AB12345"
            }
        }],
        "status": "send",
        "changes": null,
        "customer": {
            "id": "7a24ed2c-c873-4fdf-91cf-3574410acc49",
            "person": {
                "id": "35b40b2f-bf40-4f71-8319-f7757de3e1f4",
                "notes": null,
                "website": null,
                "addresses": [{
                    "id": "7a7f1e44-f6a6-495e-893b-e5806289ea81",
                    "city": "Dortmund",
                    "street": "Fakestreet",
                    "postal_code": "44339",
                    "address_type": "private",
                    "house_number": "123"
                }, {
                    "id": "1d8c41e5-bcd6-4842-864d-62c4da2fc506",
                    "city": "Bochum",
                    "street": "Fakestreet",
                    "postal_code": "44866",
                    "address_type": "work",
                    "house_number": "321"
                }],
                "last_name": "Hake",
                "birth_date": null,
                "first_name": "Jan Frederik",
                "phone_numbers": [{
                    "id": "618d19d6-3daf-4029-8d0f-1535272ec212",
                    "phone_number": "+49123456789",
                    "communication_type": "private",
                    "communication_network": "landline",
                    "is_primary_phone_number": true
                }, {
                    "id": "81403e1d-1055-4953-8b1a-fcca9d034b1b",
                    "phone_number": "+49151123456789",
                    "communication_type": "private",
                    "communication_network": "cellular_network",
                    "is_primary_phone_number": false
                }],
                "email_addresses": [{
                    "id": "a2f79f62-a497-4bdb-8f1b-03d6b7aacb30",
                    "email_address": "jan_hake@fake.de",
                    "communication_type": "private",
                    "is_primary_email_address": false
                }]
            },
            "customer_number": "AB123456"
        },
        "created_at": "2017-07-16T21:15:41.81893",
        "updated_at": "2017-07-16T21:25:03.02978",
        "purchase_order_number": "PO12345"
    }

This approach looks promising. 
In the [next part](/blog/databasearchitectureparttree.html), we look into updating those structures.

[dbArchitecturePart1]: /blog/databasearchitecture.html
[personUpdateFunction]: /blog/databasearchitecture.html#json-column
