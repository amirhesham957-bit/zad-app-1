-- A tagged Amazon search (shopping list, pantry, chef) has no catalogue
-- product behind it, so its click row has no product_id. The insert policy
-- (auth.uid() = user_id OR user_id IS NULL) already allows the row; only the
-- NOT NULL on product_id stood in the way.
alter table affiliate_clicks alter column product_id drop not null;
