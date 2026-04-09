-- ============================================================
-- DinkMate — Complete Database Schema
-- Platform: Supabase (PostgreSQL 15)
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";  -- for geo/location queries

-- ============================================================
-- USERS & PROFILES
-- ============================================================

CREATE TABLE public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username        TEXT UNIQUE NOT NULL,
  full_name       TEXT NOT NULL,
  avatar_url      TEXT,
  cover_url       TEXT,
  bio             TEXT,
  location_city   TEXT,
  location_country TEXT DEFAULT 'US',
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  dupr_rating     NUMERIC(3,1) CHECK (dupr_rating >= 1.0 AND dupr_rating <= 7.0),
  dupr_updated_at TIMESTAMPTZ,
  play_style      TEXT CHECK (play_style IN ('dinker','banger','all-court','social')),
  skill_level     TEXT CHECK (skill_level IN ('beginner','intermediate','advanced','pro')),
  availability    TEXT[] DEFAULT '{}',   -- ['weekday_am','weekday_pm','weekends']
  paddle_brand    TEXT,
  years_playing   INTEGER DEFAULT 0,
  gender          TEXT CHECK (gender IN ('male','female','non-binary','prefer_not')),
  age             INTEGER CHECK (age >= 18 AND age <= 120),
  is_verified     BOOLEAN DEFAULT FALSE,
  is_coach        BOOLEAN DEFAULT FALSE,
  subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free','pro','elite')),
  subscription_expires_at TIMESTAMPTZ,
  total_games     INTEGER DEFAULT 0,
  total_wins      INTEGER DEFAULT 0,
  total_followers INTEGER DEFAULT 0,
  total_following INTEGER DEFAULT 0,
  total_posts     INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for location-based matching
CREATE INDEX idx_profiles_location ON public.profiles USING GIST (
  ST_SetSRID(ST_MakePoint(lng, lat), 4326)
) WHERE lat IS NOT NULL AND lng IS NOT NULL;

CREATE INDEX idx_profiles_dupr ON public.profiles(dupr_rating) WHERE dupr_rating IS NOT NULL;
CREATE INDEX idx_profiles_subscription ON public.profiles(subscription_tier);

-- ============================================================
-- FOLLOWS
-- ============================================================

CREATE TABLE public.follows (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX idx_follows_follower ON public.follows(follower_id);
CREATE INDEX idx_follows_following ON public.follows(following_id);

-- ============================================================
-- POSTS (feed, reels, stories)
-- ============================================================

CREATE TABLE public.posts (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type         TEXT NOT NULL CHECK (type IN ('post','reel','story','sponsored')),
  caption      TEXT,
  media_urls   TEXT[] DEFAULT '{}',
  media_types  TEXT[] DEFAULT '{}',   -- ['image','video']
  thumbnail_url TEXT,
  location_name TEXT,
  lat          DOUBLE PRECISION,
  lng          DOUBLE PRECISION,
  hashtags     TEXT[] DEFAULT '{}',
  tagged_users UUID[] DEFAULT '{}',
  tagged_gear  TEXT,
  match_score  JSONB,                 -- {my_score: 11, opp_score: 7}
  is_sponsored BOOLEAN DEFAULT FALSE,
  sponsor_brand TEXT,
  sponsor_deal_value NUMERIC(10,2),
  views        INTEGER DEFAULT 0,
  likes_count  INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  shares_count INTEGER DEFAULT 0,
  is_deleted   BOOLEAN DEFAULT FALSE,
  expires_at   TIMESTAMPTZ,           -- for stories (24h)
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_posts_user ON public.posts(user_id, created_at DESC);
CREATE INDEX idx_posts_feed ON public.posts(created_at DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_posts_hashtags ON public.posts USING GIN(hashtags);
CREATE INDEX idx_posts_stories ON public.posts(expires_at) WHERE type = 'story';

-- ============================================================
-- LIKES
-- ============================================================

CREATE TABLE public.likes (
  id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id  UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

CREATE INDEX idx_likes_post ON public.likes(post_id);
CREATE INDEX idx_likes_user ON public.likes(user_id);

-- ============================================================
-- COMMENTS
-- ============================================================

CREATE TABLE public.comments (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  parent_id  UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  content    TEXT NOT NULL CHECK (char_length(content) <= 1000),
  likes_count INTEGER DEFAULT 0,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_comments_post ON public.comments(post_id, created_at);

-- ============================================================
-- SWIPES (matching engine)
-- ============================================================

CREATE TABLE public.swipes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  swiper_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  direction   TEXT NOT NULL CHECK (direction IN ('right','left','super')),
  is_super    BOOLEAN DEFAULT FALSE,
  match_type  TEXT CHECK (match_type IN ('partner','coach','tournament','casual')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(swiper_id, target_id)
);

CREATE INDEX idx_swipes_swiper ON public.swipes(swiper_id, created_at DESC);
CREATE INDEX idx_swipes_target ON public.swipes(target_id);

-- ============================================================
-- MATCHES
-- ============================================================

CREATE TABLE public.matches (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user2_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  match_type   TEXT CHECK (match_type IN ('partner','coach','tournament','casual')),
  status       TEXT DEFAULT 'active' CHECK (status IN ('active','archived','blocked')),
  is_super_match BOOLEAN DEFAULT FALSE,
  last_message_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  CHECK (user1_id < user2_id),       -- prevent duplicates
  UNIQUE(user1_id, user2_id)
);

CREATE INDEX idx_matches_user1 ON public.matches(user1_id, created_at DESC);
CREATE INDEX idx_matches_user2 ON public.matches(user2_id, created_at DESC);

-- ============================================================
-- MESSAGES
-- ============================================================

CREATE TABLE public.messages (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id     UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content      TEXT CHECK (char_length(content) <= 2000),
  media_url    TEXT,
  media_type   TEXT CHECK (media_type IN ('image','video','voice','gif')),
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text','media','game_invite','court_booking','system')),
  metadata     JSONB,                -- for game invites, court bookings etc.
  is_read      BOOLEAN DEFAULT FALSE,
  read_at      TIMESTAMPTZ,
  is_deleted   BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_match ON public.messages(match_id, created_at);
CREATE INDEX idx_messages_sender ON public.messages(sender_id);
CREATE INDEX idx_messages_unread ON public.messages(match_id) WHERE is_read = FALSE;

-- ============================================================
-- GROUP CHATS
-- ============================================================

CREATE TABLE public.group_chats (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  description TEXT,
  avatar_url  TEXT,
  created_by  UUID NOT NULL REFERENCES public.profiles(id),
  member_ids  UUID[] DEFAULT '{}',
  admin_ids   UUID[] DEFAULT '{}',
  is_court_channel BOOLEAN DEFAULT FALSE,
  court_location TEXT,
  last_message_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.group_messages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id    UUID NOT NULL REFERENCES public.group_chats(id) ON DELETE CASCADE,
  sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content     TEXT,
  media_url   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_group_messages_group ON public.group_messages(group_id, created_at);

-- ============================================================
-- MARKETPLACE — PRODUCTS
-- ============================================================

CREATE TABLE public.products (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  description     TEXT,
  category        TEXT NOT NULL CHECK (category IN ('paddle','ball','apparel','footwear','bag','court_booking','coaching','event_ticket','experience','other')),
  condition       TEXT CHECK (condition IN ('new','like_new','good','fair','poor')),
  price           NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  original_price  NUMERIC(10,2),
  currency        TEXT DEFAULT 'USD',
  images          TEXT[] DEFAULT '{}',
  brand           TEXT,
  model           TEXT,
  size            TEXT,
  color           TEXT,
  quantity        INTEGER DEFAULT 1,
  is_available    BOOLEAN DEFAULT TRUE,
  is_verified     BOOLEAN DEFAULT FALSE,  -- authenticated by DinkMate
  location_city   TEXT,
  location_country TEXT DEFAULT 'US',
  shipping_available BOOLEAN DEFAULT TRUE,
  local_pickup    BOOLEAN DEFAULT FALSE,
  views           INTEGER DEFAULT 0,
  saves           INTEGER DEFAULT 0,
  is_sponsored    BOOLEAN DEFAULT FALSE,
  is_deleted      BOOLEAN DEFAULT FALSE,
  sold_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_products_seller ON public.products(seller_id);
CREATE INDEX idx_products_category ON public.products(category) WHERE is_available = TRUE AND is_deleted = FALSE;
CREATE INDEX idx_products_price ON public.products(price) WHERE is_available = TRUE;

-- ============================================================
-- ORDERS
-- ============================================================

CREATE TABLE public.orders (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  buyer_id        UUID NOT NULL REFERENCES public.profiles(id),
  seller_id       UUID NOT NULL REFERENCES public.profiles(id),
  product_id      UUID NOT NULL REFERENCES public.products(id),
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','shipped','delivered','disputed','refunded','cancelled')),
  amount          NUMERIC(10,2) NOT NULL,
  platform_fee    NUMERIC(10,2),         -- DinkMate's cut (8%)
  seller_payout   NUMERIC(10,2),
  currency        TEXT DEFAULT 'USD',
  stripe_payment_intent_id TEXT,
  stripe_transfer_id TEXT,
  shipping_address JSONB,
  tracking_number TEXT,
  carrier         TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_buyer ON public.orders(buyer_id, created_at DESC);
CREATE INDEX idx_orders_seller ON public.orders(seller_id, created_at DESC);

-- ============================================================
-- SAVED / WISHLIST
-- ============================================================

CREATE TABLE public.saved_products (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

-- ============================================================
-- COURTS & EVENTS
-- ============================================================

CREATE TABLE public.courts (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  address     TEXT,
  city        TEXT,
  country     TEXT DEFAULT 'US',
  lat         DOUBLE PRECISION,
  lng         DOUBLE PRECISION,
  indoor      BOOLEAN DEFAULT FALSE,
  num_courts  INTEGER DEFAULT 1,
  hourly_rate NUMERIC(10,2),
  amenities   TEXT[],
  images      TEXT[],
  phone       TEXT,
  website     TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.events (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizer_id    UUID REFERENCES public.profiles(id),
  title           TEXT NOT NULL,
  description     TEXT,
  type            TEXT CHECK (type IN ('tournament','open_play','clinic','social','league')),
  court_id        UUID REFERENCES public.courts(id),
  location_name   TEXT,
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  starts_at       TIMESTAMPTZ NOT NULL,
  ends_at         TIMESTAMPTZ,
  skill_min       NUMERIC(3,1),
  skill_max       NUMERIC(3,1),
  capacity        INTEGER,
  tickets_sold    INTEGER DEFAULT 0,
  price           NUMERIC(10,2) DEFAULT 0,
  currency        TEXT DEFAULT 'USD',
  images          TEXT[],
  is_cancelled    BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.event_registrations (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id   UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status     TEXT DEFAULT 'confirmed' CHECK (status IN ('confirmed','waitlist','cancelled')),
  paid_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE public.notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('match','message','like','comment','follow','super_dink','brand_deal','earning','badge','system')),
  title       TEXT NOT NULL,
  body        TEXT,
  data        JSONB,                  -- {post_id, match_id, amount, etc.}
  actor_id    UUID REFERENCES public.profiles(id),
  is_read     BOOLEAN DEFAULT FALSE,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON public.notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id) WHERE is_read = FALSE;

-- ============================================================
-- ANALYTICS EVENTS
-- ============================================================

CREATE TABLE public.analytics_events (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  session_id TEXT NOT NULL,
  event_name TEXT NOT NULL,
  screen     TEXT,
  properties JSONB DEFAULT '{}',
  device_type TEXT,
  platform   TEXT,
  app_version TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_analytics_user ON public.analytics_events(user_id, created_at DESC);
CREATE INDEX idx_analytics_event ON public.analytics_events(event_name, created_at DESC);
CREATE INDEX idx_analytics_session ON public.analytics_events(session_id);

-- ============================================================
-- CREATOR EARNINGS
-- ============================================================

CREATE TABLE public.creator_earnings (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  creator_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type         TEXT NOT NULL CHECK (type IN ('reel_bonus','brand_deal','affiliate','tip','subscription')),
  amount       NUMERIC(10,2) NOT NULL,
  currency     TEXT DEFAULT 'USD',
  post_id      UUID REFERENCES public.posts(id),
  brand_name   TEXT,
  description  TEXT,
  status       TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','paid','rejected')),
  period_start DATE,
  period_end   DATE,
  paid_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_earnings_creator ON public.creator_earnings(creator_id, created_at DESC);

-- ============================================================
-- BADGES & ACHIEVEMENTS
-- ============================================================

CREATE TABLE public.badges (
  id          TEXT PRIMARY KEY,             -- e.g. 'kitchen_legend'
  name        TEXT NOT NULL,
  description TEXT NOT NULL,
  icon        TEXT,
  category    TEXT CHECK (category IN ('skill','social','marketplace','event','milestone'))
);

CREATE TABLE public.user_badges (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_id   TEXT NOT NULL REFERENCES public.badges(id),
  earned_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, badge_id)
);

-- Seed core badges
INSERT INTO public.badges (id, name, description, icon, category) VALUES
  ('first_dink',      'First Dink',        'Made your first match',                    '🏓', 'milestone'),
  ('kitchen_legend',  'Kitchen Legend',    'Won 50 dink rallies',                      '👑', 'skill'),
  ('grand_slam',      'Grand Slam',        'Won a tournament',                         '🏆', 'milestone'),
  ('social_butterfly','Social Butterfly',  'Followed by 100+ players',                 '🦋', 'social'),
  ('gear_head',       'Gear Head',         'Listed 5+ items in marketplace',           '🛍', 'marketplace'),
  ('creator_gold',    'Creator Gold',      'Earned $100+ from content',                '💛', 'social'),
  ('ace_server',      'Ace Server',        '10 aces in a single session',              '⚡', 'skill'),
  ('super_dinker',    'Super Dinker',       'Sent 10 Super Dinks',                      '⭐', 'social');

-- ============================================================
-- AUTOMATED TRIGGERS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at    BEFORE UPDATE ON public.profiles    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_posts_updated_at       BEFORE UPDATE ON public.posts       FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_products_updated_at    BEFORE UPDATE ON public.products    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_orders_updated_at      BEFORE UPDATE ON public.orders      FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-update post like counts
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_like_count
  AFTER INSERT OR DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

-- Auto-update follower counts
CREATE OR REPLACE FUNCTION update_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET total_followers = total_followers + 1 WHERE id = NEW.following_id;
    UPDATE public.profiles SET total_following = total_following + 1 WHERE id = NEW.follower_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET total_followers = GREATEST(0, total_followers - 1) WHERE id = OLD.following_id;
    UPDATE public.profiles SET total_following = GREATEST(0, total_following - 1) WHERE id = OLD.follower_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_follow_counts
  AFTER INSERT OR DELETE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION update_follow_counts();

-- Auto-create match when both users swipe right
CREATE OR REPLACE FUNCTION check_mutual_swipe()
RETURNS TRIGGER AS $$
DECLARE
  v_user1 UUID; v_user2 UUID;
BEGIN
  IF NEW.direction IN ('right','super') THEN
    IF EXISTS (
      SELECT 1 FROM public.swipes
      WHERE swiper_id = NEW.target_id
        AND target_id = NEW.swiper_id
        AND direction IN ('right','super')
    ) THEN
      v_user1 := LEAST(NEW.swiper_id, NEW.target_id);
      v_user2 := GREATEST(NEW.swiper_id, NEW.target_id);
      INSERT INTO public.matches (user1_id, user2_id, is_super_match)
        VALUES (v_user1, v_user2, NEW.direction = 'super')
        ON CONFLICT (user1_id, user2_id) DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mutual_swipe
  AFTER INSERT ON public.swipes
  FOR EACH ROW EXECUTE FUNCTION check_mutual_swipe();

-- ============================================================
-- VIEWS (convenience queries)
-- ============================================================

-- Feed view (posts with author info)
CREATE VIEW public.feed_view AS
SELECT
  p.id, p.type, p.caption, p.media_urls, p.media_types,
  p.hashtags, p.is_sponsored, p.sponsor_brand,
  p.views, p.likes_count, p.comments_count,
  p.location_name, p.created_at,
  pr.id AS author_id, pr.username, pr.full_name,
  pr.avatar_url, pr.is_verified, pr.is_coach,
  pr.subscription_tier
FROM public.posts p
JOIN public.profiles pr ON pr.id = p.user_id
WHERE p.is_deleted = FALSE
  AND (p.expires_at IS NULL OR p.expires_at > NOW())
ORDER BY p.created_at DESC;

-- Match view with both profiles
CREATE VIEW public.match_view AS
SELECT
  m.id AS match_id, m.status, m.match_type,
  m.is_super_match, m.last_message_at, m.created_at,
  p1.id AS user1_id, p1.username AS user1_username,
  p1.full_name AS user1_name, p1.avatar_url AS user1_avatar,
  p1.dupr_rating AS user1_dupr,
  p2.id AS user2_id, p2.username AS user2_username,
  p2.full_name AS user2_name, p2.avatar_url AS user2_avatar,
  p2.dupr_rating AS user2_dupr
FROM public.matches m
JOIN public.profiles p1 ON p1.id = m.user1_id
JOIN public.profiles p2 ON p2.id = m.user2_id
WHERE m.status = 'active';
