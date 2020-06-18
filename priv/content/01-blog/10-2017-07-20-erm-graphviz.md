# Generate a ERM from a PostgreSQL database schema

Creating a [ERM][ERM] is one of the first tasks, when a database is designed.
During implementation, you have to sync the model with the schema.
This manual task can be very annoying.
With some database knowledge and some Linux standard tools, this task can be automated.

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
        schema;
        label="Database";
    }

    subgraph cluster_1 {
        style=filled;
        color=lightgrey;
        node [style="filled,rounded",color=white,shape=box];
        schema -> awk -> dot;
        label="bash";
    }

    schema [ label = "database\nschema" ];
    awk [ label = "awk\nprocessing" ];
    dot [ label = "graphviz\nprocessing "];
}

```

<!--more-->

# get the schema

The [information_schema][informationschema] exists in all databases. 

    $ psql -U postgres -c "SELECT table_name, column_name, data_type, udt_name \
    > FROM information_schema.columns WHERE table_schema = 'test'" | head
           table_name       |       column_name        |          data_type          |       udt_name        
    ------------------------+--------------------------+-----------------------------+-----------------------
     person_to_email        | id_person                | uuid                        | uuid
     person_to_email        | id_email                 | uuid                        | uuid
     person_to_email        | communication_type       | USER-DEFINED                | communication_type
     person_to_email        | is_primary_email_address | boolean                     | bool
     person_to_email        | created_at               | timestamp without time zone | timestamp
     person_to_email        | updated_at               | timestamp without time zone | timestamp
     person_view            | first_name               | character varying           | varchar
     person_view            | last_name                | character varying           | varchar

These are all the columns from our test schema.
We still need some information about references between the relations.
For the next processing step, all of the necessary column data should be in one result record.

With the key column constraints  

    $ psql -U postgres -c "SELECT constraint_name, table_name, column_name \
    > FROM information_schema.key_column_usage WHERE table_schema = 'test'" | head
                  constraint_name               |       table_name       |      column_name      
    --------------------------------------------+------------------------+-----------------------
     person_to_email_id_email_fkey              | person_to_email        | id_email
     person_to_email_id_person_fkey             | person_to_email        | id_person
     person_to_email_pkey                       | person_to_email        | id_person
     person_to_email_pkey                       | person_to_email        | id_email
     person_pkey                                | person                 | id
     address_pkey                               | address                | id
     employee_id_person_fkey                    | employee               | id_person
     employee_pkey                              | employee               | id

and a list of [table_constraints][tableconstraints],

    $ psql -U postgres -c "SELECT constraint_name, table_name, constraint_type \
    > FROM information_schema.table_constraints WHERE table_schema = 'test' \
    > AND constraint_type IN ('FOREIGN KEY','PRIMARY KEY')" | head
                  constraint_name               |       table_name       | constraint_type
    --------------------------------------------+------------------------+-----------------
     person_pkey                                | person                 | PRIMARY KEY
     address_pkey                               | address                | PRIMARY KEY
     person_to_address_pkey                     | person_to_address      | PRIMARY KEY
     person_to_address_id_person_fkey           | person_to_address      | FOREIGN KEY
     person_to_address_id_address_fkey          | person_to_address      | FOREIGN KEY
     email_pkey                                 | email                  | PRIMARY KEY
     person_to_email_pkey                       | person_to_email        | PRIMARY KEY
     person_to_email_id_person_fkey             | person_to_email        | FOREIGN KEY

we can build our first query.

    $ psql -U postgres -c "SELECT c.table_name, 
    > c.column_name, 
    > c.data_type, 
    > c.udt_name,
    > is_nullable, 
    > c.character_maximum_length,
    > (SELECT tc.constraint_type FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc 
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         WHERE c.column_name = kcu.column_name 
    >                 AND c.table_name = kcu.table_name 
    >                 AND tc.constraint_type = 'PRIMARY KEY' LIMIT 1
    > ) primary_key
    > FROM information_schema.columns c 
    >         JOIN information_schema.tables t on c.table_name = t.table_name
    > WHERE c.table_schema = 'test' AND t.table_type = 'BASE TABLE'" | head
           table_name       |       column_name        |          data_type          |       udt_name        | is_nullable | character_maximum_length | primary_key 
    ------------------------+--------------------------+-----------------------------+-----------------------+-------------+--------------------------+-------------
     person_to_email        | id_person                | uuid                        | uuid                  | NO          |                          | PRIMARY KEY
     person_to_email        | id_email                 | uuid                        | uuid                  | NO          |                          | PRIMARY KEY
     person_to_email        | communication_type       | USER-DEFINED                | communication_type    | NO          |                          | 
     person_to_email        | is_primary_email_address | boolean                     | bool                  | NO          |                          | 
     person_to_email        | created_at               | timestamp without time zone | timestamp             | NO          |                          | 
     person_to_email        | updated_at               | timestamp without time zone | timestamp             | NO          |                          | 
     person                 | id                       | uuid                        | uuid                  | NO          |                          | PRIMARY KEY
     person                 | first_name               | character varying           | varchar               | YES         |                      512 | 

Now we need the foreign keys and the target of the relation.
These information can be fetched from the [constraint_column_usage view][constraintcolumnusage].

    $ psql -U postgres -c "SELECT table_name, column_name, constraint_name FROM information_schema.constraint_column_usage \
    > WHERE table_schema = 'test'" | head
           table_name       |      column_name      |              constraint_name               
    ------------------------+-----------------------+--------------------------------------------
     person                 | id                    | person_pkey
     address                | id                    | address_pkey
     person_to_address      | id_person             | person_to_address_pkey
     person_to_address      | id_address            | person_to_address_pkey
     person                 | id                    | person_to_address_id_person_fkey
     address                | id                    | person_to_address_id_address_fkey
     email                  | id                    | email_pkey
     person_to_email        | id_person             | person_to_email_pkey

With this we are coming to our next query.

    $  psql -U postgres -c "SELECT c.table_name,
    > c.column_name,
    > c.data_type,
    > c.udt_name,
    > c.is_nullable,
    > c.character_maximum_length,
    > (SELECT tc.constraint_type FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         WHERE c.column_name = kcu.column_name
    >                 AND c.table_name = kcu.table_name
    >                 AND tc.constraint_type = 'PRIMARY KEY' LIMIT 1
    > ) primary_key,
    > (SELECT tc.constraint_type FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         WHERE c.column_name = kcu.column_name
    >                 AND c.table_name = kcu.table_name
    >                 AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    > ) foreign_key,
    > (SELECT ccu.table_name FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         JOIN information_schema.constraint_column_usage ccu
    >                 ON tc.constraint_name = ccu.constraint_name
    >         WHERE c.column_name = kcu.column_name
    >                 AND c.table_name = kcu.table_name
    >                 AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    > ) reference_table,
    > (SELECT ccu.column_name FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         JOIN information_schema.constraint_column_usage ccu
    >                 ON tc.constraint_name = ccu.constraint_name
    >         WHERE c.column_name = kcu.column_name
    >                 AND c.table_name = kcu.table_name
    >                 AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    > ) reference_column
    >
    > FROM information_schema.columns c
    >         JOIN information_schema.tables t on c.table_name = t.table_name
    > WHERE c.table_schema = 'test' AND t.table_type = 'BASE TABLE'" | head
           table_name       |       column_name        |          data_type          |       udt_name        | is_nullable | character_maximum_length | primary_key | foreign_key | reference_table | reference_column
    ------------------------+--------------------------+-----------------------------+-----------------------+-------------+--------------------------+-------------+-------------+-----------------+------------------
     person_to_email        | id_person                | uuid                        | uuid                  | NO          |                          | PRIMARY KEY | FOREIGN KEY | person          | id
     person_to_email        | id_email                 | uuid                        | uuid                  | NO          |                          | PRIMARY KEY | FOREIGN KEY | email           | id
     person_to_email        | communication_type       | USER-DEFINED                | communication_type    | NO          |                          |             |             |                 |
     person_to_email        | is_primary_email_address | boolean                     | bool                  | NO          |                          |             |             |                 |
     person_to_email        | created_at               | timestamp without time zone | timestamp             | NO          |                          |             |             |                 |
     person_to_email        | updated_at               | timestamp without time zone | timestamp             | NO          |                          |             |             |                 |
     person                 | id                       | uuid                        | uuid                  | NO          |                          | PRIMARY KEY |             |                 |
     person                 | first_name               | character varying           | varchar               | YES         |                      512 |             |             |                 |

There is one thing left. 
It would be nice, if you can see the enum values within the ERM.
Let's look, what we can do about it.

    $ psql -U postgres -c "SELECT e.enumlabel, t.typname FROM pg_type t \
    > JOIN pg_enum e ON t.oid = e.enumtypid \
    > JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace"  | head
           enumlabel        |        typname
    ------------------------+-----------------------
     work                   | address_type
     invoice                | address_type
     delivery               | address_type
     private                | address_type
     organization           | communication_type
     private                | communication_type
     work                   | communication_type
     cellular_network       | communication_network

This can be matched on the column `udt_name`.

Now we have our final SQL statement for now.

    $ psql -U postgres -c "SELECT c.table_name, 
    > c.column_name, 
    > c.data_type, 
    > c.udt_name,
    > (SELECT string_agg(e.enumlabel::TEXT, ', ')
    >         FROM pg_type t 
    >            JOIN pg_enum e on t.oid = e.enumtypid  
    >            JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace WHERE t.typname = c.udt_name) enum_values,
    > c.is_nullable, 
    > c.character_maximum_length,
    > (SELECT tc.constraint_type FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc 
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         WHERE c.column_name = kcu.column_name 
    >                 AND c.table_name = kcu.table_name 
    >                 AND tc.constraint_type = 'PRIMARY KEY' LIMIT 1
    > ) primary_key,
    > (SELECT tc.constraint_type FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc 
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         WHERE c.column_name = kcu.column_name 
    >                 AND c.table_name = kcu.table_name 
    >                 AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    > ) foreign_key,
    > (SELECT ccu.table_name FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc 
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         JOIN information_schema.constraint_column_usage ccu
    >                 ON tc.constraint_name = ccu.constraint_name
    >         WHERE c.column_name = kcu.column_name 
    >                 AND c.table_name = kcu.table_name 
    >                 AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    > ) reference_table,
    > (SELECT ccu.column_name FROM information_schema.key_column_usage kcu
    >         JOIN information_schema.table_constraints tc 
    >                 ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    >         JOIN information_schema.constraint_column_usage ccu
    >                 ON tc.constraint_name = ccu.constraint_name
    >         WHERE c.column_name = kcu.column_name 
    >                 AND c.table_name = kcu.table_name 
    >                 AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    > ) reference_column
    > 
    > FROM information_schema.columns c 
    >         JOIN information_schema.tables t on c.table_name = t.table_name
    > WHERE c.table_schema = 'test' AND t.table_type = 'BASE TABLE'" | head
           table_name       |       column_name        |          data_type          |       udt_name        |                                     enum_values                                     | is_nullable | character_maximum_length | primary_key | foreign_key | reference_table | reference_column 
    ------------------------+--------------------------+-----------------------------+-----------------------+-------------------------------------------------------------------------------------+-------------+--------------------------+-------------+-------------+-----------------+------------------
     person_to_email        | id_person                | uuid                        | uuid                  |                                                                                     | NO          |                          | PRIMARY KEY | FOREIGN KEY | person          | id
     person_to_email        | id_email                 | uuid                        | uuid                  |                                                                                     | NO          |                          | PRIMARY KEY | FOREIGN KEY | email           | id
     person_to_email        | communication_type       | USER-DEFINED                | communication_type    | work, private, organization                                                         | NO          |                          |             |             |                 | 
     person_to_email        | is_primary_email_address | boolean                     | bool                  |                                                                                     | NO          |                          |             |             |                 | 
     person_to_email        | created_at               | timestamp without time zone | timestamp             |                                                                                     | NO          |                          |             |             |                 | 
     person_to_email        | updated_at               | timestamp without time zone | timestamp             |                                                                                     | NO          |                          |             |             |                 | 
     person                 | id                       | uuid                        | uuid                  |                                                                                     | NO          |                          | PRIMARY KEY |             |                 | 
     person                 | first_name               | character varying           | varchar               |                                                                                     | YES         |                      512 |             |             |                 | 

The `string_agg` function is used to concentrate the enum values.

# a look ahead

Before starting to work with the raw schema data, we take a look at our goal.
We use graphviz for drawing the ERM. 
My goal is to get close to a ERM visualization.


    digraph {
        node [shape=Mrecord; fontname="Courier New" style="filled, bold" fillcolor="white", fontcolor="black"];
        customer [shape=plaintext; label=<
         <TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3">
         <TR>
            <TD COLSPAN="5" BGCOLOR="black"><FONT color="white"><B>customer</B></FONT></TD>
         </TR>
         <TR>
            <TD>column</TD>
            <TD>type</TD>
            <TD>nullable</TD>
            <TD>PK</TD>
            <TD>FK</TD>
         </TR>
         <TR>
            <TD port="f1">id</TD>
            <TD>uuid</TD>
            <TD>NO</TD>
            <TD>PRIMARY KEY</TD>
            <TD></TD>
         </TR>
         <TR>
            <TD port="f2">id_person</TD>
            <TD>uuid</TD>
            <TD>NO</TD>
            <TD></TD>
            <TD>FOREIGN KEY</TD>
         </TR>
         <TR>
            <TD port="f3">customer_number</TD>
            <TD>varchar</TD>
            <TD>NO</TD>
            <TD></TD>
            <TD></TD>
         </TR>
         <TR>
            <TD port="f4">json_view</TD>
            <TD>jsonb</TD>
            <TD>YES</TD>
            <TD></TD>
            <TD></TD>
         </TR>
         <TR>
            <TD port="f5">created_at</TD>
            <TD>timestamp</TD>
            <TD>NO</TD>
            <TD></TD>
            <TD></TD>
         </TR>
         <TR>
            <TD port="f6">updated_at</TD>
            <TD>timestamp</TD>
            <TD>NO</TD>
            <TD></TD>
            <TD></TD>
         </TR>
         </TABLE>>]
    }

```{lang=dot}
digraph {
    node [shape=Mrecord; fontname="Courier New" style="filled, bold" fillcolor="white", fontcolor="black"];
 customer [shape=plaintext; label=<
 <TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3">
 <TR>
 <TD COLSPAN="5" BGCOLOR="black"><FONT color="white"><B>customer</B></FONT></TD>
 </TR>
 <TR>
 <TD>column</TD>
 <TD>type</TD>
 <TD>nullable</TD>
 <TD>PK</TD>
 <TD>FK</TD>
 </TR>
 <TR>
 <TD port="f1">id</TD>
 <TD>uuid</TD>
 <TD>NO</TD>
 <TD>PRIMARY KEY</TD>
 <TD></TD>
 </TR>
 <TR>
 <TD port="f2">id_person</TD>
 <TD>uuid</TD>
 <TD>NO</TD>
 <TD></TD>
 <TD>FOREIGN KEY</TD>
 </TR>
 <TR>
 <TD port="f3">customer_number</TD>
 <TD>varchar</TD>
 <TD>NO</TD>
 <TD></TD>
 <TD></TD>
 </TR>
 <TR>
 <TD port="f4">json_view</TD>
 <TD>jsonb</TD>
 <TD>YES</TD>
 <TD></TD>
 <TD></TD>
 </TR>
 <TR>
 <TD port="f5">created_at</TD>
 <TD>timestamp</TD>
 <TD>NO</TD>
 <TD></TD>
 <TD></TD>
 </TR>
 <TR>
 <TD port="f6">updated_at</TD>
 <TD>timestamp</TD>
 <TD>NO</TD>
 <TD></TD>
 <TD></TD>
 </TR>
 </TABLE>>]
}
```

The table column layout fits our needs for our relation.
The `port` attribute is important for the edges.

If we have a `person` and a `customer`, adding

    customer -> person;

will create an edge for these relations.

```{lang=dot}
    digraph {
        node [shape=Mrecord; fontname="Courier New" style="filled, bold" fillcolor="white", fontcolor="black"];
    person [shape=plaintext; label=<
    <TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3">
    <TR>
    <TD COLSPAN="5" BGCOLOR="black"><FONT color="white"><B>person</B></FONT></TD>
    </TR>
    <TR>
    <TD>column</TD>
    <TD>type</TD>
    <TD>nullable</TD>
    <TD>PK</TD>
    <TD>FK</TD>
    </TR>
    <TR>
    <TD port="f1">id</TD>
    <TD>uuid</TD>
    <TD>NO</TD>
    <TD>PRIMARY KEY</TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f2">first_name</TD>
    <TD>varchar</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f3">last_name</TD>
    <TD>varchar</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f4">birth_date</TD>
    <TD>date</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f5">notes</TD>
    <TD>varchar</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f6">website</TD>
    <TD>varchar</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f7">json_view</TD>
    <TD>jsonb</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f8">created_at</TD>
    <TD>timestamp</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f9">updated_at</TD>
    <TD>timestamp</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    </TABLE>>]
    
     customer [shape=plaintext; label=<
     <TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3">
     <TR>
     <TD COLSPAN="5" BGCOLOR="black"><FONT color="white"><B>customer</B></FONT></TD>
     </TR>
     <TR>
     <TD>column</TD>
     <TD>type</TD>
     <TD>nullable</TD>
     <TD>PK</TD>
     <TD>FK</TD>
     </TR>
     <TR>
     <TD port="f1">id</TD>
     <TD>uuid</TD>
     <TD>NO</TD>
     <TD>PRIMARY KEY</TD>
     <TD></TD>
     </TR>
     <TR>
     <TD port="f2">id_person</TD>
     <TD>uuid</TD>
     <TD>NO</TD>
     <TD></TD>
     <TD>FOREIGN KEY</TD>
     </TR>
     <TR>
     <TD port="f3">customer_number</TD>
     <TD>varchar</TD>
     <TD>NO</TD>
     <TD></TD>
     <TD></TD>
     </TR>
     <TR>
     <TD port="f4">json_view</TD>
     <TD>jsonb</TD>
     <TD>YES</TD>
     <TD></TD>
     <TD></TD>
     </TR>
     <TR>
     <TD port="f5">created_at</TD>
     <TD>timestamp</TD>
     <TD>NO</TD>
     <TD></TD>
     <TD></TD>
     </TR>
     <TR>
     <TD port="f6">updated_at</TD>
     <TD>timestamp</TD>
     <TD>NO</TD>
     <TD></TD>
     <TD></TD>
     </TR>
     </TABLE>>]
    
    customer -> person;
    }
```

# preparations

First we export the schema to a file (e.g. `schema.txt`).
This file will be used for the awk processing.

The first two lines of the head

    $ head -n 5 schema.txt
           table_name       |       column_name        |          data_type          |       udt_name        |                                     enum_values                                     | is_nullable | character_maximum_length | primary_key | foreign_key | reference_table | reference_column 
    ------------------------+--------------------------+-----------------------------+-----------------------+-------------------------------------------------------------------------------------+-------------+--------------------------+-------------+-------------+-----------------+------------------
     person                 | id                       | uuid                        | uuid                  |                                                                                     | NO          |                          | PRIMARY KEY |             |                 | 
     person                 | first_name               | character varying           | varchar               |                                                                                     | YES         |                      512 |             |             |                 | 
     person                 | last_name                | character varying           | varchar               |                                                                                     | YES         |                      512 |             |             |                 | 

must be removed.
This can be done by

    $ head -n5 schema.txt | tail -n+3
     person                 | id                       | uuid                        | uuid                  |                                                                                     | NO          |                          | PRIMARY KEY |             |                 | 
     person                 | first_name               | character varying           | varchar               |                                                                                     | YES         |                      512 |             |             |                 | 
     person                 | last_name                | character varying           | varchar               |                                                                                     | YES         |                      512 |             |             |                 | 

The last two lines (one blank line) of the tail

     article                | status                   | USER-DEFINED                | article_status        | active, inactive                                                                    | NO          |                          |             |             |                 |
     article                | created_at               | timestamp without time zone | timestamp             |                                                                                     | NO          |                          |             |             |                 |
     article                | updated_at               | timestamp without time zone | timestamp             |                                                                                     | NO          |                          |             |             |                 |
    (109 Zeilen)
        
can be removed with

    $ tail -n 5 schema.txt | head -n -2
     article                | status                   | USER-DEFINED                | article_status        | active, inactive                                                                    | NO          |                          |             |             |                 |
     article                | created_at               | timestamp without time zone | timestamp             |                                                                                     | NO          |                          |             |             |                 |
     article                | updated_at               | timestamp without time zone | timestamp             |                                                                                     | NO          |                          |             |             |                 |

Now we have a record in every line.

# get started with awk

An awk program has the following structure.


```{lang=dot}
digraph {
    rankdir=LR;
    bgcolor=lightgrey;

    node [fontname="helvetica",style="filled,rounded",color=white,shape=box];
    graph [fontname="helvetica"];
    edge [fontname="helvetica"];


    begin [ label = "BEGIN" ];
    middle [ label = "middle part" ];
    end [ label = "END"];

    begin -> middle -> end;
}
```

The BEGIN and the END part is executed once. 
The middle part is executed for every data record.

The BEGIN part introduces the graph.

    BEGIN {
        print("digraph {")
        print("graph [overlap=false;splines=true;regular=true];")
        print("node [shape=Mrecord; fontname=\"Courier New\" style=\"filled, bold\" fillcolor=\"white\", fontcolor=\"black\"];")
    }

The middle part must print every graphviz table for every relation in the schema.

    {
       if (length(currentTableName) > 0 && $1 != currentTableName) {
           print("</TABLE>>]")
       }
     
       if ($1 != currentTableName) {
            print("")
            print(trim($1) " [shape=plaintext; label=<")
            print("<TABLE BORDER=\"1\" CELLBORDER=\"0\" CELLSPACING=\"0\" CELLPADDING=\"3\">")
            print("<TR>")
            print("<TD COLSPAN=\"5\" BGCOLOR=\"black\"><FONT color=\"white\"><B>" trim($1) "</B></FONT></TD>")
            print("</TR>")
    
            print("<TR>")
            print("<TD>column</TD>")
            print("<TD>type</TD>")
            print("<TD>nullable</TD>")
            print("<TD>PK</TD>")
            print("<TD>FK</TD>")
            print("</TR>")
            port = 0
        }
    
        print("<TR>")
        print("<TD port=\"f" ++port "\">"trim($2)"</TD>")
        print("<TD>"trim($4)"</TD>")
        print("<TD>"trim($6)"</TD>")
        print("<TD>"trim($8)"</TD>")
        print("<TD>"trim($9)"</TD>")
        print("</TR>")
    
        currentTableName = $1
    }

The END part closes the last TABLE and closes the graph.

    END {
        print("</TABLE>>]")
        print("}")
    }

This script will generate graphviz tables for all relations in the database schema.


```{lang=dot}
    digraph {
    graph [overlap=false;splines=true;regular=true];
    node [shape=Mrecord; fontname="Courier New" style="filled, bold" fillcolor="white", fontcolor="black"];
    
    purchase_order [shape=plaintext; label=<
    <TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3">
    <TR>
    <TD COLSPAN="5" BGCOLOR="black"><FONT color="white"><B>purchase_order</B></FONT></TD>
    </TR>
    <TR>
    <TD>column</TD>
    <TD>type</TD>
    <TD>nullable</TD>
    <TD>PK</TD>
    <TD>FK</TD>
    </TR>
    <TR>
    <TD port="f1">id</TD>
    <TD>uuid</TD>
    <TD>NO</TD>
    <TD>PRIMARY KEY</TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f2">id_customer</TD>
    <TD>uuid</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD>FOREIGN KEY</TD>
    </TR>
    <TR>
    <TD port="f3">purchase_order_number</TD>
    <TD>varchar</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f4">status</TD>
    <TD>purchase_order_status</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f5">frozen_purchase_order</TD>
    <TD>jsonb</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f6">changes</TD>
    <TD>jsonb</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f7">created_at</TD>
    <TD>timestamp</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f8">updated_at</TD>
    <TD>timestamp</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    </TABLE>>]
    
    purchase_order_item [shape=plaintext; label=<
    <TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3">
    <TR>
    <TD COLSPAN="5" BGCOLOR="black"><FONT color="white"><B>purchase_order_item</B></FONT></TD>
    </TR>
    <TR>
    <TD>column</TD>
    <TD>type</TD>
    <TD>nullable</TD>
    <TD>PK</TD>
    <TD>FK</TD>
    </TR>
    <TR>
    <TD port="f1">id</TD>
    <TD>uuid</TD>
    <TD>NO</TD>
    <TD>PRIMARY KEY</TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f2">id_article</TD>
    <TD>uuid</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD>FOREIGN KEY</TD>
    </TR>
    <TR>
    <TD port="f3">id_price</TD>
    <TD>uuid</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD>FOREIGN KEY</TD>
    </TR>
    <TR>
    <TD port="f4">amount</TD>
    <TD>int4</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f5">changes</TD>
    <TD>jsonb</TD>
    <TD>YES</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f6">created_at</TD>
    <TD>timestamp</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    <TR>
    <TD port="f7">updated_at</TD>
    <TD>timestamp</TD>
    <TD>NO</TD>
    <TD></TD>
    <TD></TD>
    </TR>
    </TABLE>>]
    
    }
```

For the edges, the middle part must be extended with

    if (trim($9) == "FOREIGN KEY") {
        edges[++edgeCounter] = trim($1) " -> " trim($10) ";"
    }

This takes the current table name and point it to the target relation.

Some relations use a enum as a datatype. 
It would be nice, if this could be visible in the ERM.

    if (length(trim($5)) > 0) {
        nodes[++nodeCounter] = trim($4) "[shape=\"box\", style=\"rounded\", label=<<B>" trim($4) " (enum)</B><BR/>" trim($5) ">];"
        edges[++edgeCounter] = trim($1) ":f" port " -> " trim($4) ";"
    }

This adds new enum nodes to the graph and points it directly to the column used by the enum.

In the END part, the new nodes and edges must be added.

    for (node in nodes) {
        print(nodes[++i])
    }
    i = 0
    for (edge in edges){
        print(edges[++i])
    }

Currently the enum values are comma separated. 
For the graph drawing it is easier, to have short lines.

A `sed 's/, /<BR\/>/g'` before script start will replace the commas with `<BR/>`.

# final

The complete script glued together

    #!/bin/bash
    
    psql -U postgres -c "
    
    SELECT c.table_name, 
    	c.column_name, 
    	c.data_type, 
    	c.udt_name,
    	(SELECT string_agg(e.enumlabel::TEXT, ', ')
    		FROM pg_type t 
    		   JOIN pg_enum e on t.oid = e.enumtypid  
    		   JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace WHERE t.typname = c.udt_name) enum_values,
    	c.is_nullable, 
    	c.character_maximum_length,
    	(SELECT tc.constraint_type FROM information_schema.key_column_usage kcu
    		JOIN information_schema.table_constraints tc 
    			ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    		WHERE c.column_name = kcu.column_name 
    			AND c.table_name = kcu.table_name 
    			AND tc.constraint_type = 'PRIMARY KEY' LIMIT 1
    	) primary_key,
    	(SELECT tc.constraint_type FROM information_schema.key_column_usage kcu
    		JOIN information_schema.table_constraints tc 
    			ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    		WHERE c.column_name = kcu.column_name 
    			AND c.table_name = kcu.table_name 
    			AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    	) foreign_key,
    	(SELECT ccu.table_name FROM information_schema.key_column_usage kcu
    		JOIN information_schema.table_constraints tc 
    			ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    		JOIN information_schema.constraint_column_usage ccu
    			ON tc.constraint_name = ccu.constraint_name
    		WHERE c.column_name = kcu.column_name 
    			AND c.table_name = kcu.table_name 
    			AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    	) reference_table,
    	(SELECT ccu.column_name FROM information_schema.key_column_usage kcu
    		JOIN information_schema.table_constraints tc 
    			ON tc.table_name = c.table_name AND tc.constraint_name = kcu.constraint_name
    		JOIN information_schema.constraint_column_usage ccu
    			ON tc.constraint_name = ccu.constraint_name
    		WHERE c.column_name = kcu.column_name 
    			AND c.table_name = kcu.table_name 
    			AND tc.constraint_type = 'FOREIGN KEY' LIMIT 1
    	) reference_column
    	
    FROM information_schema.columns c 
    	JOIN information_schema.tables t on c.table_name = t.table_name
    WHERE c.table_schema = 'test' AND t.table_type = 'BASE TABLE'" | sed 's/, /<BR\/>/g' | head -n -2 | tail -n+3 | awk -F"|" '
    function ltrim(s) {
        sub(/^[ \t\r\n]+/, "", s);
        return s
    }
    
    function rtrim(s) {
        sub(/[ \t\r\n]+$/, "", s);
        return s
    }
    
    function trim(s) {
        return rtrim(ltrim(s));
    }
    
    BEGIN {
        print("digraph {")
        print("graph [overlap=false;splines=true;regular=true];")
        print("node [shape=Mrecord; fontname=\"Courier New\" style=\"filled, bold\" fillcolor=\"white\", fontcolor=\"black\"];")
    }
    
    {
       if (length(currentTableName) > 0 && $1 != currentTableName) {
           print("</TABLE>>]")
       }
     
       if ($1 != currentTableName) {
            print("")
            print(trim($1) " [shape=plaintext; label=<")
            print("<TABLE BORDER=\"1\" CELLBORDER=\"0\" CELLSPACING=\"0\" CELLPADDING=\"3\">")
            print("<TR>")
            print("<TD COLSPAN=\"5\" BGCOLOR=\"black\"><FONT color=\"white\"><B>" trim($1) "</B></FONT></TD>")
            print("</TR>")
    
            print("<TR>")
            print("<TD>column</TD>")
            print("<TD>type</TD>")
            print("<TD>nullable</TD>")
            print("<TD>PK</TD>")
            print("<TD>FK</TD>")
            print("</TR>")
            port = 0
        }
    
        print("<TR>")
        print("<TD port=\"f" ++port "\">"trim($2)"</TD>")
        print("<TD>"trim($4)"</TD>")
        print("<TD>"trim($6)"</TD>")
        print("<TD>"trim($8)"</TD>")
        print("<TD>"trim($9)"</TD>")
        print("</TR>")
    
        if (trim($9) == "FOREIGN KEY") {
            edges[++edgeCounter] = trim($1) " -> " trim($10) ";"
        }
    
        if (length(trim($5)) > 0) {
            nodes[++nodeCounter] = trim($4) "[shape=\"box\", style=\"rounded\", label=<<B>" trim($4) " (enum)</B><BR/>" trim($5) ">];"
            edges[++edgeCounter] = trim($1) ":f" port " -> " trim($4) ";"
        }
       
        currentTableName = $1
    }
    
    END {
        print("</TABLE>>]")
    
        for (node in nodes) {
            print(nodes[++i])
        }
        i = 0
        for (edge in edges){
            print(edges[++i])
        }
        print("}")
    }'


I have put the result in a [external file][result] because the graph has become to big in size.
Not so bad, I think.

Update 2017-10-12: 

I added a [schema.sh][schema] script to my [script collection][scripts].



[ERM]: https://en.wikipedia.org/wiki/Entity%E2%80%93relationship_model
[informationschema]: https://www.postgresql.org/docs/current/static/information-schema.html
[tables]: https://www.postgresql.org/docs/current/static/infoschema-tables.html
[keycolumnusage]: https://www.postgresql.org/docs/current/static/infoschema-key-column-usage.html
[tableconstraints]: https://www.postgresql.org/docs/current/static/infoschema-table-constraints.html
[referentialconstraints]: https://www.postgresql.org/docs/current/static/infoschema-referential-constraints.html
[constraintcolumnusage]: https://www.postgresql.org/docs/current/static/infoschema-constraint-column-usage.html
[result]: /images/schema.svg
[schema]: https://github.com/enter-haken/scripts/blob/master/schema.sh
[scripts]: https://github.com/enter-haken/scripts
