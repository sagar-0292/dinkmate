// ============================================================
// DinkMate — Supabase Database Client
// src/db.js
// ============================================================
// This file is embedded directly in index.html via a <script> block.
// To use: include the Supabase CDN and configure SUPABASE_URL/KEY.
// ============================================================

(function() {
  // ── CONFIG (set these before deploying) ──
  var SUPABASE_URL = window.DINKMATE_CONFIG?.supabaseUrl || 'https://YOUR-PROJECT.supabase.co';
  var SUPABASE_KEY = window.DINKMATE_CONFIG?.supabaseKey || 'YOUR-ANON-KEY';

  // ── INIT CLIENT ──
  // Requires: <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  var supabase = null;
  if (window.supabase) {
    supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
    console.log('[DinkMate DB] Supabase connected');
  } else {
    console.warn('[DinkMate DB] Supabase not loaded — running in demo mode');
  }

  // ── EXPOSE AS GLOBAL ──
  window.DM_DB = {

    // ── AUTH ──
    auth: {
      signUp: async function(email, password, userData) {
        if (!supabase) return { error: 'Demo mode' };
        var { data, error } = await supabase.auth.signUp({
          email, password,
          options: { data: userData }
        });
        if (data.user && !error) {
          await window.DM_DB.profiles.create({
            id: data.user.id,
            username: userData.username,
            full_name: userData.full_name,
            ...userData
          });
        }
        return { data, error };
      },

      signIn: async function(email, password) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.auth.signInWithPassword({ email, password });
      },

      signOut: async function() {
        if (!supabase) return;
        return supabase.auth.signOut();
      },

      getUser: async function() {
        if (!supabase) return { data: { user: null } };
        return supabase.auth.getUser();
      },

      onAuthChange: function(callback) {
        if (!supabase) return;
        return supabase.auth.onAuthStateChange(callback);
      }
    },

    // ── PROFILES ──
    profiles: {
      create: async function(profile) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.from('profiles').insert(profile).select().single();
      },

      get: async function(userId) {
        if (!supabase) return { data: null };
        return supabase.from('profiles').select('*').eq('id', userId).single();
      },

      update: async function(userId, updates) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.from('profiles').update(updates).eq('id', userId).select().single();
      },

      search: async function(query) {
        if (!supabase) return { data: [] };
        return supabase.from('profiles')
          .select('id,username,full_name,avatar_url,dupr_rating,is_verified')
          .or(`username.ilike.%${query}%,full_name.ilike.%${query}%`)
          .limit(20);
      },

      // Get players for matching deck
      getMatchDeck: async function(userId, filters) {
        if (!supabase) return { data: [] };
        var q = supabase.from('profiles')
          .select('*')
          .neq('id', userId)
          .limit(50);
        if (filters?.duprMin) q = q.gte('dupr_rating', filters.duprMin);
        if (filters?.duprMax) q = q.lte('dupr_rating', filters.duprMax);
        if (filters?.playStyle) q = q.eq('play_style', filters.playStyle);
        // Exclude already-swiped users
        var { data: swiped } = await supabase
          .from('swipes').select('target_id').eq('swiper_id', userId);
        if (swiped?.length) {
          var swipedIds = swiped.map(function(s) { return s.target_id; });
          q = q.not('id', 'in', '(' + swipedIds.join(',') + ')');
        }
        return q;
      }
    },

    // ── FOLLOWS ──
    follows: {
      follow: async function(followerId, followingId) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.from('follows')
          .insert({ follower_id: followerId, following_id: followingId });
      },
      unfollow: async function(followerId, followingId) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
      },
      isFollowing: async function(followerId, followingId) {
        if (!supabase) return false;
        var { data } = await supabase.from('follows')
          .select('id').eq('follower_id', followerId)
          .eq('following_id', followingId).single();
        return !!data;
      }
    },

    // ── POSTS ──
    posts: {
      create: async function(post) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.from('posts').insert(post).select().single();
      },

      getFeed: async function(userId, page) {
        if (!supabase) return { data: [] };
        var offset = (page || 0) * 20;
        return supabase.from('feed_view')
          .select('*')
          .order('created_at', { ascending: false })
          .range(offset, offset + 19);
      },

      getByUser: async function(userId, type) {
        if (!supabase) return { data: [] };
        var q = supabase.from('posts')
          .select('*').eq('user_id', userId).eq('is_deleted', false);
        if (type) q = q.eq('type', type);
        return q.order('created_at', { ascending: false });
      },

      delete: async function(postId, userId) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.from('posts')
          .update({ is_deleted: true }).eq('id', postId).eq('user_id', userId);
      }
    },

    // ── LIKES ──
    likes: {
      toggle: async function(userId, postId) {
        if (!supabase) return { liked: false };
        var { data: existing } = await supabase.from('likes')
          .select('id').eq('user_id', userId).eq('post_id', postId).single();
        if (existing) {
          await supabase.from('likes').delete().eq('id', existing.id);
          return { liked: false };
        } else {
          await supabase.from('likes').insert({ user_id: userId, post_id: postId });
          return { liked: true };
        }
      },
      isLiked: async function(userId, postId) {
        if (!supabase) return false;
        var { data } = await supabase.from('likes')
          .select('id').eq('user_id', userId).eq('post_id', postId).single();
        return !!data;
      }
    },

    // ── SWIPES ──
    swipes: {
      record: async function(swiperId, targetId, direction, matchType) {
        if (!supabase) return { data: null, matched: false };
        var { data, error } = await supabase.from('swipes').insert({
          swiper_id: swiperId,
          target_id: targetId,
          direction: direction,
          is_super: direction === 'super',
          match_type: matchType || 'partner'
        }).select().single();
        // Check if a match was auto-created by trigger
        if (direction !== 'left') {
          var u1 = swiperId < targetId ? swiperId : targetId;
          var u2 = swiperId < targetId ? targetId : swiperId;
          var { data: match } = await supabase.from('matches')
            .select('id').eq('user1_id', u1).eq('user2_id', u2).single();
          return { data, error, matched: !!match, matchId: match?.id };
        }
        return { data, error, matched: false };
      }
    },

    // ── MATCHES ──
    matches: {
      getAll: async function(userId) {
        if (!supabase) return { data: [] };
        return supabase.from('match_view')
          .select('*')
          .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
          .order('last_message_at', { ascending: false, nullsFirst: false });
      }
    },

    // ── MESSAGES ──
    messages: {
      send: async function(matchId, senderId, content, type) {
        if (!supabase) return { error: 'Demo mode' };
        var { data, error } = await supabase.from('messages').insert({
          match_id: matchId,
          sender_id: senderId,
          content: content,
          message_type: type || 'text'
        }).select().single();
        // Update match last_message_at
        await supabase.from('matches')
          .update({ last_message_at: new Date().toISOString() }).eq('id', matchId);
        return { data, error };
      },

      getThread: async function(matchId) {
        if (!supabase) return { data: [] };
        return supabase.from('messages')
          .select('*, sender:profiles(username,full_name,avatar_url)')
          .eq('match_id', matchId)
          .eq('is_deleted', false)
          .order('created_at', { ascending: true });
      },

      // Real-time subscription
      subscribe: function(matchId, callback) {
        if (!supabase) return null;
        return supabase.channel('match_' + matchId)
          .on('postgres_changes', {
            event: 'INSERT', schema: 'public', table: 'messages',
            filter: 'match_id=eq.' + matchId
          }, callback)
          .subscribe();
      }
    },

    // ── PRODUCTS ──
    products: {
      create: async function(product) {
        if (!supabase) return { error: 'Demo mode' };
        return supabase.from('products').insert(product).select().single();
      },

      list: async function(filters) {
        if (!supabase) return { data: [] };
        var q = supabase.from('products')
          .select('*, seller:profiles(username,full_name,avatar_url,is_verified)')
          .eq('is_available', true).eq('is_deleted', false);
        if (filters?.category) q = q.eq('category', filters.category);
        if (filters?.maxPrice) q = q.lte('price', filters.maxPrice);
        return q.order('created_at', { ascending: false }).limit(50);
      },

      view: async function(productId) {
        if (!supabase) return;
        return supabase.rpc('increment_product_views', { product_id: productId });
      }
    },

    // ── ANALYTICS ──
    analytics: {
      track: async function(userId, sessionId, eventName, screen, props) {
        if (!supabase) return;
        return supabase.from('analytics_events').insert({
          user_id: userId || null,
          session_id: sessionId,
          event_name: eventName,
          screen: screen,
          properties: props || {},
          platform: 'web',
          app_version: '1.0.0'
        });
      }
    },

    // ── DATA EXPORT (user's own data — GDPR) ──
    export: {
      myData: async function(userId) {
        if (!supabase) return null;
        console.log('[DinkMate] Exporting data for user:', userId);
        var [profile, posts, swipes, matches, messages, orders, analytics] = await Promise.all([
          supabase.from('profiles').select('*').eq('id', userId).single(),
          supabase.from('posts').select('*').eq('user_id', userId),
          supabase.from('swipes').select('*').eq('swiper_id', userId),
          supabase.from('match_view').select('*').or('user1_id.eq.' + userId + ',user2_id.eq.' + userId),
          supabase.from('messages').select('*').eq('sender_id', userId),
          supabase.from('orders').select('*').or('buyer_id.eq.' + userId + ',seller_id.eq.' + userId),
          supabase.from('analytics_events').select('*').eq('user_id', userId)
        ]);
        return {
          exported_at: new Date().toISOString(),
          user_id: userId,
          profile: profile.data,
          posts: posts.data,
          swipes: swipes.data,
          matches: matches.data,
          messages: messages.data,
          orders: orders.data,
          analytics: analytics.data
        };
      },

      // Download user's data as JSON file
      download: async function(userId) {
        var data = await window.DM_DB.export.myData(userId);
        if (!data) { alert('Export failed. Please try again.'); return; }
        var blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'dinkmate-my-data-' + new Date().toISOString().slice(0, 10) + '.json';
        a.click();
        URL.revokeObjectURL(a.href);
      }
    },

    // ── DELETE ACCOUNT ──
    deleteAccount: async function(userId) {
      if (!supabase) return { error: 'Demo mode' };
      // Soft-delete profile (cascades to all user data via FK)
      await supabase.from('profiles').update({ username: '[deleted]', bio: null, avatar_url: null }).eq('id', userId);
      return supabase.auth.admin.deleteUser(userId);
    }
  };

  console.log('[DinkMate DB] Client ready');
})();
