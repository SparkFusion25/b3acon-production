/*
# Complete B3ACON Database Schema

1. Core Tables
   - Users and profiles
   - Clients and projects
   - CRM (leads, deals, activities)
   
2. Marketing Features
   - Affiliate marketing
   - Email marketing
   - Landing pages
   
3. Security
   - Row Level Security policies
   - Performance indexes
   - Update triggers
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom enum types (if they don't exist)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('admin', 'manager', 'specialist', 'client');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_tier') THEN
    CREATE TYPE subscription_tier AS ENUM ('starter', 'professional', 'enterprise');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lead_status') THEN
    CREATE TYPE lead_status AS ENUM ('new', 'qualified', 'contacted', 'nurturing', 'converted', 'lost');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'deal_stage') THEN
    CREATE TYPE deal_stage AS ENUM ('prospecting', 'qualification', 'proposal', 'negotiation', 'closed_won', 'closed_lost');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'activity_type') THEN
    CREATE TYPE activity_type AS ENUM ('email', 'call', 'meeting', 'note', 'task');
  END IF;
END $$;

-- Create tables if they don't exist
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  role user_role DEFAULT 'client',
  company_name TEXT,
  phone TEXT,
  timezone TEXT DEFAULT 'UTC',
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS clients (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  logo_url TEXT,
  website TEXT,
  industry TEXT,
  subscription_tier subscription_tier DEFAULT 'starter',
  monthly_value INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active',
  services JSONB DEFAULT '[]',
  settings JSONB DEFAULT '{}',
  assigned_manager UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leads (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  company TEXT,
  phone TEXT,
  website TEXT,
  source TEXT,
  status lead_status DEFAULT 'new',
  score INTEGER DEFAULT 0 CHECK (score >= 0 AND score <= 100),
  estimated_value INTEGER DEFAULT 0,
  notes TEXT,
  tags JSONB DEFAULT '[]',
  custom_fields JSONB DEFAULT '{}',
  assigned_to UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS deals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  value INTEGER NOT NULL,
  stage deal_stage DEFAULT 'prospecting',
  probability INTEGER DEFAULT 0 CHECK (probability >= 0 AND probability <= 100),
  close_date DATE,
  description TEXT,
  lead_id UUID REFERENCES leads(id),
  client_id UUID REFERENCES clients(id),
  assigned_to UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS activities (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  type activity_type NOT NULL,
  subject TEXT NOT NULL,
  description TEXT,
  scheduled_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  lead_id UUID REFERENCES leads(id),
  deal_id UUID REFERENCES deals(id),
  client_id UUID REFERENCES clients(id),
  assigned_to UUID REFERENCES auth.users(id),
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'active',
  start_date DATE,
  end_date DATE,
  budget INTEGER,
  services JSONB DEFAULT '[]',
  client_id UUID NOT NULL REFERENCES clients(id),
  assigned_team JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS affiliates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  company TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('active', 'pending', 'suspended', 'inactive')),
  tier TEXT DEFAULT 'bronze' CHECK (tier IN ('bronze', 'silver', 'gold', 'platinum')),
  commission_rate DECIMAL(5,2) DEFAULT 10.00,
  total_earnings DECIMAL(10,2) DEFAULT 0.00,
  total_referrals INTEGER DEFAULT 0,
  conversion_rate DECIMAL(5,2) DEFAULT 0.00,
  payment_method TEXT DEFAULT 'paypal' CHECK (payment_method IN ('paypal', 'bank_transfer', 'check')),
  payment_details JSONB DEFAULT '{}',
  referral_code TEXT UNIQUE NOT NULL,
  joined_date TIMESTAMPTZ DEFAULT NOW(),
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS affiliate_links (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  campaign_name TEXT NOT NULL,
  original_url TEXT NOT NULL,
  tracking_url TEXT UNIQUE NOT NULL,
  clicks INTEGER DEFAULT 0,
  conversions INTEGER DEFAULT 0,
  revenue DECIMAL(10,2) DEFAULT 0.00,
  commission_earned DECIMAL(10,2) DEFAULT 0.00,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS affiliate_referrals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  client_name TEXT NOT NULL,
  client_email TEXT NOT NULL,
  service_type TEXT NOT NULL,
  deal_value DECIMAL(10,2) NOT NULL,
  commission_amount DECIMAL(10,2) NOT NULL,
  status TEXT DEFAULT 'lead' CHECK (status IN ('lead', 'qualified', 'converted', 'lost')),
  referral_date TIMESTAMPTZ DEFAULT NOW(),
  conversion_date TIMESTAMPTZ,
  tracking_data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS affiliate_commissions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  referral_id UUID REFERENCES affiliate_referrals(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  commission_rate DECIMAL(5,2) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'cancelled')),
  transaction_date TIMESTAMPTZ DEFAULT NOW(),
  payment_date TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_campaigns (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  subject TEXT NOT NULL,
  preview_text TEXT,
  content TEXT NOT NULL,
  template_id UUID,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'sending', 'sent', 'paused')),
  campaign_type TEXT DEFAULT 'newsletter' CHECK (campaign_type IN ('newsletter', 'promotional', 'automated', 'transactional')),
  client_id UUID REFERENCES clients(id),
  list_ids JSONB DEFAULT '[]',
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  stats JSONB DEFAULT '{"total_sent": 0, "delivered": 0, "opened": 0, "clicked": 0, "bounced": 0, "unsubscribed": 0, "spam_complaints": 0, "open_rate": 0, "click_rate": 0, "bounce_rate": 0, "unsubscribe_rate": 0}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_lists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  client_id UUID REFERENCES clients(id),
  subscriber_count INTEGER DEFAULT 0,
  active_subscribers INTEGER DEFAULT 0,
  growth_rate DECIMAL(5,2) DEFAULT 0.00,
  tags JSONB DEFAULT '[]',
  custom_fields JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_subscribers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  company TEXT,
  status TEXT DEFAULT 'subscribed' CHECK (status IN ('subscribed', 'unsubscribed', 'bounced', 'complained')),
  source TEXT,
  subscribed_at TIMESTAMPTZ DEFAULT NOW(),
  unsubscribed_at TIMESTAMPTZ,
  tags JSONB DEFAULT '[]',
  custom_fields JSONB DEFAULT '{}',
  engagement_score INTEGER DEFAULT 0,
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_automations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  trigger_type TEXT NOT NULL CHECK (trigger_type IN ('signup', 'purchase', 'abandoned_cart', 'birthday', 'custom')),
  trigger_conditions JSONB DEFAULT '{}',
  status TEXT DEFAULT 'draft' CHECK (status IN ('active', 'paused', 'draft')),
  client_id UUID REFERENCES clients(id),
  steps JSONB DEFAULT '[]',
  stats JSONB DEFAULT '{"total_triggered": 0, "completed": 0, "conversion_rate": 0, "revenue_generated": 0}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_templates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT DEFAULT 'custom' CHECK (category IN ('newsletter', 'promotional', 'welcome', 'abandoned_cart', 'custom')),
  html_content TEXT NOT NULL,
  text_content TEXT,
  thumbnail TEXT,
  is_public BOOLEAN DEFAULT false,
  usage_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS landing_pages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  slug TEXT UNIQUE NOT NULL,
  domain TEXT,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  template_id UUID,
  client_id UUID REFERENCES clients(id),
  content JSONB DEFAULT '{"sections": [], "global_styles": {}, "custom_css": "", "custom_js": ""}',
  seo JSONB DEFAULT '{"meta_title": "", "meta_description": "", "meta_keywords": [], "og_title": "", "og_description": "", "og_image": "", "canonical_url": "", "robots": "index,follow", "schema_markup": {}}',
  settings JSONB DEFAULT '{"favicon": "", "google_analytics_id": "", "facebook_pixel_id": "", "custom_tracking_codes": [], "password_protection": {"enabled": false, "password": ""}, "redirect_after_conversion": "", "thank_you_page": ""}',
  analytics JSONB DEFAULT '{"total_views": 0, "unique_visitors": 0, "conversions": 0, "conversion_rate": 0, "bounce_rate": 0, "avg_time_on_page": 0, "traffic_sources": [], "device_breakdown": {"desktop": 0, "mobile": 0, "tablet": 0}, "geographic_data": []}',
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS landing_page_templates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT DEFAULT 'custom' CHECK (category IN ('business', 'ecommerce', 'saas', 'agency', 'event', 'custom')),
  thumbnail TEXT,
  preview_url TEXT,
  content JSONB DEFAULT '{"sections": [], "global_styles": {}}',
  is_premium BOOLEAN DEFAULT false,
  usage_count INTEGER DEFAULT 0,
  rating DECIMAL(3,2) DEFAULT 0.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS landing_page_forms (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  landing_page_id UUID REFERENCES landing_pages(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  fields JSONB DEFAULT '[]',
  settings JSONB DEFAULT '{"submit_button_text": "Submit", "success_message": "Thank you!", "error_message": "Please try again", "redirect_url": "", "email_notifications": {"enabled": false, "recipients": [], "subject": ""}, "auto_responder": {"enabled": false, "subject": "", "message": ""}}',
  integrations JSONB DEFAULT '[]',
  analytics JSONB DEFAULT '{"total_submissions": 0, "conversion_rate": 0, "abandonment_rate": 0, "avg_completion_time": 0, "field_analytics": []}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS form_submissions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  form_id UUID REFERENCES landing_page_forms(id) ON DELETE CASCADE,
  data JSONB NOT NULL,
  ip_address INET,
  user_agent TEXT,
  referrer TEXT,
  status TEXT DEFAULT 'new' CHECK (status IN ('new', 'processed', 'spam')),
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS white_label_partners (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  company_name TEXT NOT NULL,
  domain TEXT UNIQUE NOT NULL,
  logo_url TEXT,
  primary_color TEXT DEFAULT '#8B5CF6',
  secondary_color TEXT DEFAULT '#EC4899',
  custom_css TEXT,
  features JSONB DEFAULT '[]',
  settings JSONB DEFAULT '{}',
  status TEXT DEFAULT 'active',
  admin_user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create a users table for API keys and other non-auth users
CREATE TABLE IF NOT EXISTS users (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create API keys table
CREATE TABLE IF NOT EXISTS api_keys (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  service TEXT NOT NULL,
  key TEXT NOT NULL,
  secret TEXT,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id)
);

-- Enable RLS on all tables
DO $$ 
BEGIN
  ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
  ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
  ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
  ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
  ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
  ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
  ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
  ALTER TABLE affiliate_links ENABLE ROW LEVEL SECURITY;
  ALTER TABLE affiliate_referrals ENABLE ROW LEVEL SECURITY;
  ALTER TABLE affiliate_commissions ENABLE ROW LEVEL SECURITY;
  ALTER TABLE email_campaigns ENABLE ROW LEVEL SECURITY;
  ALTER TABLE email_lists ENABLE ROW LEVEL SECURITY;
  ALTER TABLE email_subscribers ENABLE ROW LEVEL SECURITY;
  ALTER TABLE email_automations ENABLE ROW LEVEL SECURITY;
  ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
  ALTER TABLE landing_pages ENABLE ROW LEVEL SECURITY;
  ALTER TABLE landing_page_templates ENABLE ROW LEVEL SECURITY;
  ALTER TABLE landing_page_forms ENABLE ROW LEVEL SECURITY;
  ALTER TABLE form_submissions ENABLE ROW LEVEL SECURITY;
  ALTER TABLE white_label_partners ENABLE ROW LEVEL SECURITY;
  ALTER TABLE users ENABLE ROW LEVEL SECURITY;
  ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- Ignore errors if RLS is already enabled
END $$;

-- Create RLS policies (only if they don't exist)
DO $$ 
DECLARE
  policy_exists boolean;
BEGIN
  -- Check if policy exists before creating
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' AND policyname = 'Users can view own profile'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' AND policyname = 'Users can update own profile'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' AND policyname = 'Users can insert own profile'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;
  
  -- Clients policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'clients' AND policyname = 'Authenticated users can view clients'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can view clients" ON clients FOR SELECT USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'clients' AND policyname = 'Authenticated users can manage clients'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage clients" ON clients FOR ALL USING (role() = 'authenticated');
  END IF;
  
  -- Leads policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'leads' AND policyname = 'Authenticated users can manage leads'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage leads" ON leads FOR ALL USING (role() = 'authenticated');
  END IF;
  
  -- Deals policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'deals' AND policyname = 'Authenticated users can manage deals'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage deals" ON deals FOR ALL USING (role() = 'authenticated');
  END IF;
  
  -- Activity policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'activities' AND policyname = 'Users can manage their activities'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Users can manage their activities" ON activities FOR ALL USING (
      (auth.uid() = assigned_to) OR (auth.uid() = created_by) OR (role() = 'authenticated')
    );
  END IF;
  
  -- Project policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'projects' AND policyname = 'Authenticated users can view projects'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can view projects" ON projects FOR SELECT USING (role() = 'authenticated');
  END IF;
  
  -- Affiliate policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'affiliates' AND policyname = 'Authenticated users can manage affiliates'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage affiliates" ON affiliates FOR ALL USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'affiliate_links' AND policyname = 'Authenticated users can view affiliate data'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can view affiliate data" ON affiliate_links FOR SELECT USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'affiliate_referrals' AND policyname = 'Authenticated users can manage affiliate referrals'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage affiliate referrals" ON affiliate_referrals FOR ALL USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'affiliate_commissions' AND policyname = 'Authenticated users can manage commissions'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage commissions" ON affiliate_commissions FOR ALL USING (role() = 'authenticated');
  END IF;
  
  -- Email marketing policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'email_campaigns' AND policyname = 'Authenticated users can manage email campaigns'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage email campaigns" ON email_campaigns FOR ALL USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'email_lists' AND policyname = 'Authenticated users can manage email lists'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage email lists" ON email_lists FOR ALL USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'email_subscribers' AND policyname = 'Authenticated users can manage subscribers'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage subscribers" ON email_subscribers FOR ALL USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'email_automations' AND policyname = 'Authenticated users can manage automations'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage automations" ON email_automations FOR ALL USING (role() = 'authenticated');
  END IF;
  
  -- Landing page policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'landing_pages' AND policyname = 'Authenticated users can manage landing pages'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage landing pages" ON landing_pages FOR ALL USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'landing_page_templates' AND policyname = 'Users can view public templates'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Users can view public templates" ON landing_page_templates FOR SELECT USING (true);
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'landing_page_forms' AND policyname = 'Authenticated users can manage forms'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage forms" ON landing_page_forms FOR ALL USING (role() = 'authenticated');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'form_submissions' AND policyname = 'Authenticated users can view form submissions'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can view form submissions" ON form_submissions FOR SELECT USING (role() = 'authenticated');
  END IF;
  
  -- White label policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'white_label_partners' AND policyname = 'Authenticated users can manage white label partners'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Authenticated users can manage white label partners" ON white_label_partners FOR ALL USING (role() = 'authenticated');
  END IF;
  
  -- Users and API keys policies
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'users' AND policyname = 'Users can view own data'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Users can view own data" ON users FOR SELECT USING (auth.uid() = id);
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'users' AND policyname = 'Admins can view all users'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Admins can view all users" ON users FOR SELECT USING (
      EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
      )
    );
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'api_keys' AND policyname = 'Admins can manage API keys'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Admins can manage API keys" ON api_keys FOR ALL USING (
      EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
      )
    );
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'api_keys' AND policyname = 'Agency users can manage API keys'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Agency users can manage API keys" ON api_keys FOR ALL USING (
      EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'manager')
      )
    );
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'api_keys' AND policyname = 'Agency users can view API keys'
  ) INTO policy_exists;
  
  IF NOT policy_exists THEN
    CREATE POLICY "Agency users can view API keys" ON api_keys FOR SELECT USING (
      EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'manager', 'specialist')
      )
    );
  END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_clients_status ON clients(status);
CREATE INDEX IF NOT EXISTS idx_clients_subscription ON clients(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_assigned_to ON leads(assigned_to);
CREATE INDEX IF NOT EXISTS idx_deals_stage ON deals(stage);
CREATE INDEX IF NOT EXISTS idx_deals_client_id ON deals(client_id);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(type);
CREATE INDEX IF NOT EXISTS idx_activities_assigned_to ON activities(assigned_to);
CREATE INDEX IF NOT EXISTS idx_projects_client_id ON projects(client_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_affiliates_status ON affiliates(status);
CREATE INDEX IF NOT EXISTS idx_affiliates_tier ON affiliates(tier);
CREATE INDEX IF NOT EXISTS idx_affiliates_referral_code ON affiliates(referral_code);
CREATE INDEX IF NOT EXISTS idx_affiliate_links_affiliate_id ON affiliate_links(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_affiliate_id ON affiliate_referrals(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_commissions_affiliate_id ON affiliate_commissions(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_email_campaigns_client_id ON email_campaigns(client_id);
CREATE INDEX IF NOT EXISTS idx_email_campaigns_status ON email_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_email_lists_client_id ON email_lists(client_id);
CREATE INDEX IF NOT EXISTS idx_email_subscribers_email ON email_subscribers(email);
CREATE INDEX IF NOT EXISTS idx_email_subscribers_status ON email_subscribers(status);
CREATE INDEX IF NOT EXISTS idx_email_automations_client_id ON email_automations(client_id);
CREATE INDEX IF NOT EXISTS idx_landing_pages_client_id ON landing_pages(client_id);
CREATE INDEX IF NOT EXISTS idx_landing_pages_slug ON landing_pages(slug);
CREATE INDEX IF NOT EXISTS idx_landing_pages_status ON landing_pages(status);
CREATE INDEX IF NOT EXISTS idx_landing_page_forms_landing_page_id ON landing_page_forms(landing_page_id);
CREATE INDEX IF NOT EXISTS idx_form_submissions_form_id ON form_submissions(form_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_service ON api_keys(service);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active);

-- Create function to handle updated_at timestamps
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at (only if they don't exist)
DO $$ 
DECLARE
  trigger_exists boolean;
BEGIN
  -- Check if trigger exists before creating
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_profiles_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_clients_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_clients_updated_at BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_leads_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_leads_updated_at BEFORE UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_deals_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_deals_updated_at BEFORE UPDATE ON deals FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_activities_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_activities_updated_at BEFORE UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_projects_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_affiliates_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_affiliates_updated_at BEFORE UPDATE ON affiliates FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_affiliate_links_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_affiliate_links_updated_at BEFORE UPDATE ON affiliate_links FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_affiliate_referrals_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_affiliate_referrals_updated_at BEFORE UPDATE ON affiliate_referrals FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_affiliate_commissions_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_affiliate_commissions_updated_at BEFORE UPDATE ON affiliate_commissions FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_email_campaigns_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_email_campaigns_updated_at BEFORE UPDATE ON email_campaigns FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_email_lists_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_email_lists_updated_at BEFORE UPDATE ON email_lists FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_email_subscribers_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_email_subscribers_updated_at BEFORE UPDATE ON email_subscribers FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_email_automations_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_email_automations_updated_at BEFORE UPDATE ON email_automations FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_email_templates_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_email_templates_updated_at BEFORE UPDATE ON email_templates FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_landing_pages_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_landing_pages_updated_at BEFORE UPDATE ON landing_pages FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_landing_page_templates_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_landing_page_templates_updated_at BEFORE UPDATE ON landing_page_templates FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_landing_page_forms_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_landing_page_forms_updated_at BEFORE UPDATE ON landing_page_forms FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_white_label_partners_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_white_label_partners_updated_at BEFORE UPDATE ON white_label_partners FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_users_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_api_keys_updated_at'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    CREATE TRIGGER handle_api_keys_updated_at BEFORE UPDATE ON api_keys FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
  END IF;
END $$;

-- Insert sample data
DO $$
BEGIN
  -- Insert sample clients
  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'contact@techcorp.com') THEN
    INSERT INTO clients (name, email, subscription_tier, monthly_value, services, industry, website)
    VALUES ('TechCorp Solutions', 'contact@techcorp.com', 'enterprise', 8500, '["SEO", "Social Media", "PPC", "Amazon", "CRM"]'::jsonb, 'Technology', 'https://techcorp.com');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'hello@retailmax.com') THEN
    INSERT INTO clients (name, email, subscription_tier, monthly_value, services, industry, website)
    VALUES ('RetailMax Inc', 'hello@retailmax.com', 'professional', 4200, '["SEO", "PPC", "Social Media"]'::jsonb, 'Retail', 'https://retailmax.com');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'team@financeflow.com') THEN
    INSERT INTO clients (name, email, subscription_tier, monthly_value, services, industry, website)
    VALUES ('FinanceFlow', 'team@financeflow.com', 'professional', 3800, '["SEO", "CRM"]'::jsonb, 'Finance', 'https://financeflow.com');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'support@ecomstore.com') THEN
    INSERT INTO clients (name, email, subscription_tier, monthly_value, services, industry, website)
    VALUES ('EcomStore', 'support@ecomstore.com', 'professional', 5200, '["Amazon", "PPC", "Social Media"]'::jsonb, 'E-commerce', 'https://ecomstore.com');
  END IF;
  
  -- Insert sample leads
  IF NOT EXISTS (SELECT 1 FROM leads WHERE email = 'sarah@techstartup.com') THEN
    INSERT INTO leads (name, email, company, source, status, score, estimated_value)
    VALUES ('Sarah Johnson', 'sarah@techstartup.com', 'TechStartup Inc', 'Website', 'qualified', 85, 15000);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM leads WHERE email = 'mike@retailcorp.com') THEN
    INSERT INTO leads (name, email, company, source, status, score, estimated_value)
    VALUES ('Mike Chen', 'mike@retailcorp.com', 'RetailCorp', 'LinkedIn', 'contacted', 72, 8500);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM leads WHERE email = 'emily@financeplus.com') THEN
    INSERT INTO leads (name, email, company, source, status, score, estimated_value)
    VALUES ('Emily Rodriguez', 'emily@financeplus.com', 'FinancePlus', 'Referral', 'nurturing', 68, 12000);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM leads WHERE email = 'david@growthco.com') THEN
    INSERT INTO leads (name, email, company, source, status, score, estimated_value)
    VALUES ('David Wilson', 'david@growthco.com', 'GrowthCo', 'Google Ads', 'new', 45, 6000);
  END IF;
  
  -- Insert sample affiliates
  IF NOT EXISTS (SELECT 1 FROM affiliates WHERE email = 'sarah@marketingpro.com') THEN
    INSERT INTO affiliates (name, email, company, status, tier, commission_rate, referral_code)
    VALUES ('Sarah Johnson', 'sarah@marketingpro.com', 'Marketing Pro Agency', 'active', 'gold', 15.00, 'SARAH2024');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM affiliates WHERE email = 'mike@digitalboost.com') THEN
    INSERT INTO affiliates (name, email, company, status, tier, commission_rate, referral_code)
    VALUES ('Mike Chen', 'mike@digitalboost.com', 'Digital Boost', 'active', 'silver', 12.00, 'MIKE2024');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM affiliates WHERE email = 'emily@growthagency.com') THEN
    INSERT INTO affiliates (name, email, company, status, tier, commission_rate, referral_code)
    VALUES ('Emily Rodriguez', 'emily@growthagency.com', 'Growth Agency', 'pending', 'bronze', 10.00, 'EMILY2024');
  END IF;
  
  -- Insert sample email campaigns
  IF NOT EXISTS (SELECT 1 FROM email_campaigns WHERE name = 'January Newsletter') THEN
    INSERT INTO email_campaigns (name, subject, content, status, campaign_type, stats)
    VALUES ('January Newsletter', 'New Year, New Marketing Strategies', '<h1>Welcome to 2024!</h1><p>Here are our top marketing strategies for the new year...</p>', 'sent', 'newsletter', '{"total_sent": 2500, "delivered": 2450, "opened": 1225, "clicked": 245, "open_rate": 50.0, "click_rate": 10.0}'::jsonb);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM email_campaigns WHERE name = 'Product Launch') THEN
    INSERT INTO email_campaigns (name, subject, content, status, campaign_type, stats)
    VALUES ('Product Launch', 'Introducing Our Revolutionary New Service', '<h1>Big News!</h1><p>We are excited to announce our latest service offering...</p>', 'scheduled', 'promotional', '{"total_sent": 0, "delivered": 0, "opened": 0, "clicked": 0, "open_rate": 0, "click_rate": 0}'::jsonb);
  END IF;
  
  -- Insert sample email templates
  IF NOT EXISTS (SELECT 1 FROM email_templates WHERE name = 'Welcome Email') THEN
    INSERT INTO email_templates (name, category, html_content, is_public)
    VALUES ('Welcome Email', 'welcome', '<h1>Welcome to B3ACON!</h1><p>Thank you for joining us. We are excited to help you grow your business.</p>', true);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM email_templates WHERE name = 'Newsletter Template') THEN
    INSERT INTO email_templates (name, category, html_content, is_public)
    VALUES ('Newsletter Template', 'newsletter', '<h1>Monthly Newsletter</h1><p>Here are this month''s updates and insights...</p>', true);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM email_templates WHERE name = 'Promotional Email') THEN
    INSERT INTO email_templates (name, category, html_content, is_public)
    VALUES ('Promotional Email', 'promotional', '<h1>Special Offer!</h1><p>Don''t miss out on this limited-time offer. Act now!</p>', true);
  END IF;
  
  -- Insert sample landing pages
  IF NOT EXISTS (SELECT 1 FROM landing_pages WHERE slug = 'saas-launch') THEN
    INSERT INTO landing_pages (name, title, slug, status, description)
    VALUES ('SaaS Product Launch', 'Revolutionary Project Management Tool', 'saas-launch', 'published', 'Perfect landing page for software launches');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM landing_pages WHERE slug = 'fashion-store') THEN
    INSERT INTO landing_pages (name, title, slug, status, description)
    VALUES ('E-commerce Store', 'Premium Fashion Collection', 'fashion-store', 'draft', 'Optimized for online retail');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM landing_pages WHERE slug = 'agency-services') THEN
    INSERT INTO landing_pages (name, title, slug, status, description)
    VALUES ('Agency Services', 'Digital Marketing Excellence', 'agency-services', 'published', 'Showcase your agency capabilities');
  END IF;
  
  -- Insert sample landing page templates
  IF NOT EXISTS (SELECT 1 FROM landing_page_templates WHERE name = 'SaaS Landing') THEN
    INSERT INTO landing_page_templates (name, category, description, is_premium)
    VALUES ('SaaS Landing', 'saas', 'Perfect for software and app launches', false);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM landing_page_templates WHERE name = 'E-commerce Store') THEN
    INSERT INTO landing_page_templates (name, category, description, is_premium)
    VALUES ('E-commerce Store', 'ecommerce', 'Optimized for online stores and products', true);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM landing_page_templates WHERE name = 'Agency Portfolio') THEN
    INSERT INTO landing_page_templates (name, category, description, is_premium)
    VALUES ('Agency Portfolio', 'agency', 'Showcase your agency services and portfolio', false);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM landing_page_templates WHERE name = 'Event Landing') THEN
    INSERT INTO landing_page_templates (name, category, description, is_premium)
    VALUES ('Event Landing', 'event', 'Perfect for conferences and events', true);
  END IF;
END $$;