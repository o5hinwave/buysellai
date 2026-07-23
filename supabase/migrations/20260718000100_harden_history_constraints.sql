do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_category_known'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_category_known
    check (
      category is null or category in (
        'electronics',
        'furniture',
        'clothing',
        'shoes',
        'bags',
        'jewelry',
        'toys',
        'kids',
        'home',
        'tools',
        'sports',
        'books',
        'media',
        'music',
        'collectibles',
        'art',
        'other'
      )
    );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_condition_known'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_condition_known
    check (
      condition is null or condition in (
        'new',
        'likeNew',
        'good',
        'fair',
        'forParts'
      )
    );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_marketplace_known'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_marketplace_known
    check (
      marketplace in (
        'ebay',
        'craigslist',
        'facebook',
        'poshmark',
        'mercari',
        'offerup',
        'depop',
        'whatnot',
        'grailed',
        'reverb',
        'etsy',
        'stockx',
        'goat',
        'kidizen',
        'vinted',
        'vestiaire',
        'therealreal',
        'swappa',
        'tradesy',
        'chairish',
        'bonanza',
        'curtsy',
        'nextdoor',
        'amazon',
        'shopify',
        'rubylane',
        'tcgplayer'
      )
    );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_listing_text_has_sections'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_listing_text_has_sections
    check (
      listing_text ~* '^[[:space:]]*title[[:space:]]*:'
      and listing_text ~* 'description[[:space:]]*:'
    );
  end if;
end $$;
