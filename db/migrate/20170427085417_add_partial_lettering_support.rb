class AddPartialLetteringSupport < ActiveRecord::Migration
  def change
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE OR REPLACE FUNCTION compute_partial_lettering() RETURNS TRIGGER AS $$
          DECLARE
            new_letter varchar DEFAULT NULL;
            old_letter varchar DEFAULT NULL;
            new_account_id integer DEFAULT NULL;
            old_account_id integer DEFAULT NULL;
          BEGIN
          IF TG_OP <> 'DELETE' THEN
            new_letter := substring(NEW.letter from '[A-z]*');
            new_account_id := NEW.account_id;
          END IF;

          IF TG_OP <> 'INSERT' THEN
            old_letter := substring(OLD.letter from '[A-z]*');
            old_account_id := OLD.account_id;
          END IF;

          UPDATE journal_entry_items
          SET letter = (CASE
                          WHEN modified_letter_groups.balance <> 0
                          THEN modified_letter_groups.letter || '*'
                          ELSE modified_letter_groups.letter
                        END)
          FROM (SELECT new_letter AS letter,
                       account_id AS account_id,
                       SUM(debit) - SUM(credit) AS balance
                    FROM journal_entry_items
                    WHERE account_id = new_account_id
                      AND letter ~ new_letter
                      AND new_letter IS NOT NULL
                      AND new_account_id IS NOT NULL
                    GROUP BY account_id
                UNION ALL
                SELECT old_letter AS letter,
                       account_id AS account_id,
                       SUM(debit) - SUM(credit) AS balance
                  FROM journal_entry_items
                  WHERE account_id = old_account_id
                    AND letter ~ old_letter
                    AND old_letter IS NOT NULL
                    AND old_account_id IS NOT NULL
                  GROUP BY account_id) AS modified_letter_groups
          WHERE modified_letter_groups.account_id = journal_entry_items.account_id
          AND journal_entry_items.letter ~ modified_letter_groups.letter;

          RETURN NEW;
        END;
        $$ language plpgsql;

          CREATE TRIGGER compute_partial_lettering_status_insert_delete
            AFTER INSERT OR DELETE 
            ON journal_entry_items
            FOR EACH ROW
              EXECUTE PROCEDURE compute_partial_lettering();

          CREATE TRIGGER compute_partial_lettering_status_update
            AFTER UPDATE OF credit, debit, account_id, letter
            ON journal_entry_items
            FOR EACH ROW
            WHEN (substring(OLD.letter from '[A-z]*') <> substring(NEW.letter from '[A-z]*')
               OR OLD.account_id <> NEW.account_id
               OR OLD.credit <> NEW.credit
               OR OLD.debit <> NEW.debit)
              EXECUTE PROCEDURE compute_partial_lettering();
        SQL
      end

      dir.down do
        execute 'DROP TRIGGER IF EXISTS compute_partial_lettering_status_insert_delete ON journal_entry_items;'
        execute 'DROP TRIGGER IF EXISTS compute_partial_lettering_status_update ON journal_entry_items;'
        execute 'DROP FUNCTION IF EXISTS compute_partial_lettering();'
      end
    end
  end
end
