-- ============================================================
-- DinkMate — Row Level Security Policies
-- Run AFTER schema.sql
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_chats         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_products      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_earnings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;

-- ── PROFILES ──
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- ── FOLLOWS ──
CREATE POLICY "Follows viewable by everyone"
  ON public.follows FOR SELECT USING (true);

CREATE POLICY "Users can follow others"
  ON public.follows FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow"
  ON public.follows FOR DELETE USING (auth.uid() = follower_id);

-- ── POSTS ──
CREATE POLICY "Posts viewable by everyone"
  ON public.posts FOR SELECT USING (is_deleted = FALSE);

CREATE POLICY "Users can create posts"
  ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own posts"
  ON public.posts FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own posts"
  ON public.posts FOR UPDATE USING (auth.uid() = user_id);

-- ── LIKES ──
CREATE POLICY "Likes viewable by everyone"
  ON public.likes FOR SELECT USING (true);

CREATE POLICY "Users can like posts"
  ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike posts"
  ON public.likes FOR DELETE USING (auth.uid() = user_id);

-- ── COMMENTS ──
CREATE POLICY "Comments viewable by everyone"
  ON public.comments FOR SELECT USING (is_deleted = FALSE);

CREATE POLICY "Users can comment"
  ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own comments"
  ON public.comments FOR UPDATE USING (auth.uid() = user_id);

-- ── SWIPES ──
CREATE POLICY "Users can see their own swipes"
  ON public.swipes FOR SELECT USING (auth.uid() = swiper_id);

CREATE POLICY "Users can swipe"
  ON public.swipes FOR INSERT WITH CHECK (auth.uid() = swiper_id);

-- ── MATCHES ──
CREATE POLICY "Users can see their own matches"
  ON public.matches FOR SELECT
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- ── MESSAGES ──
CREATE POLICY "Users can see messages in their matches"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = match_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their matches"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = match_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

-- ── PRODUCTS ──
CREATE POLICY "Products viewable by everyone"
  ON public.products FOR SELECT USING (is_deleted = FALSE);

CREATE POLICY "Users can list products"
  ON public.products FOR INSERT WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Sellers can update own products"
  ON public.products FOR UPDATE USING (auth.uid() = seller_id);

-- ── ORDERS ──
CREATE POLICY "Users see their own orders"
  ON public.orders FOR SELECT
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

CREATE POLICY "Users can create orders"
  ON public.orders FOR INSERT WITH CHECK (auth.uid() = buyer_id);

-- ── NOTIFICATIONS ──
CREATE POLICY "Users see own notifications"
  ON public.notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can mark notifications read"
  ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- ── ANALYTICS ──
CREATE POLICY "Users can insert own analytics"
  ON public.analytics_events FOR INSERT WITH CHECK (
    auth.uid() = user_id OR user_id IS NULL
  );

CREATE POLICY "Users can read own analytics"
  ON public.analytics_events FOR SELECT USING (auth.uid() = user_id);

-- ── EARNINGS ──
CREATE POLICY "Creators see own earnings"
  ON public.creator_earnings FOR SELECT USING (auth.uid() = creator_id);

-- ── BADGES ──
CREATE POLICY "Badges viewable by everyone"
  ON public.user_badges FOR SELECT USING (true);

-- ── SAVED PRODUCTS ──
CREATE POLICY "Users see own saved products"
  ON public.saved_products FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can save products"
  ON public.saved_products FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unsave products"
  ON public.saved_products FOR DELETE USING (auth.uid() = user_id);

-- ── EVENT REGISTRATIONS ──
CREATE POLICY "Users see own registrations"
  ON public.event_registrations FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can register for events"
  ON public.event_registrations FOR INSERT WITH CHECK (auth.uid() = user_id);
