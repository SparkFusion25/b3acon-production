import React, { useState } from 'react';
import { Globe, Calculator, DollarSign, FileCheck, Truck, Package, Search, BarChart3, ShieldCheck, Lock, CreditCard } from 'lucide-react';
import { supabase } from '../../../../lib/supabase';
import TariffCalculator from './TariffCalculator';
import LandedCostEstimator from './LandedCostEstimator';
import ComplianceChecker from './ComplianceChecker';
import FreightEstimator from './FreightEstimator';
import ShipmentTracker from './ShipmentTracker';
import HSCodeFinder from './HSCodeFinder';
import FTAChecker from './FTAChecker';
import { toast } from 'react-hot-toast';

const GlobalCommerceHub: React.FC = () => {
  const [activeTab, setActiveTab] = useState('tariff');
  const [userSubscription, setUserSubscription] = useState<'starter'|'pro'|'enterprise'>('starter');
  const [pluginAccess, setPluginAccess] = useState<Record<string, string>>({
    'tariff': 'starter', 
    'landed_cost': 'pro',
    'compliance': 'starter',
    'freight': 'pro',
    'tracker': 'starter',
    'hs_finder': 'starter',
    'fta': 'pro'
  });
  const [isLoading, setIsLoading] = useState(true);

  // Fetch user subscription and plugin access settings
  React.useEffect(() => {
    const fetchUserSubscription = async () => {
      setIsLoading(true);
      try {
        if (!supabase) {
          throw new Error('Supabase not configured');
        }
        // Get the current user
        const { data: { user } } = await supabase.auth.getUser();
        
        if (!user) {
          setIsLoading(false);
          return;
        }
        
        // Get the user's subscription
        const { data: subscriptionData, error: subscriptionError } = await supabase
          .from('commerce_subscriptions')
          .select('*')
          .eq('user_id', user.id)
          .single();
        
        if (subscriptionError) {
          console.error('Error fetching subscription:', subscriptionError);
        } else if (subscriptionData) {
          setUserSubscription(subscriptionData.subscription_level as any);
        }
        
        // Get global commerce settings
        const { data: settingsData, error: settingsError } = await supabase
          .from('admin_settings')
          .select('value')
          .eq('key', 'global_commerce_settings')
          .single();
        
        if (settingsError) {
          console.error('Error fetching global commerce settings:', settingsError);
        } else if (settingsData && settingsData.value && settingsData.value.plugin_access) {
          setPluginAccess(settingsData.value.plugin_access);
        }
      } catch (error) {
        console.error('Error:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchUserSubscription();
  }, []);

  const checkAccess = (plugin: string): boolean => {
    // This would check against the user's actual subscription
    const pluginLevel = pluginAccess[plugin] || 'enterprise';
    
    // For demo purposes, we'll grant access to starter features
    // and show upgrade prompts for others
    if (pluginLevel === 'starter') {
      return true;
    }
    
    // For admin users, grant access to all features
    // In a real implementation, check user role
    const isAdmin = localStorage.getItem('isAdmin') === 'true';
    if (isAdmin) {
      return true;
    }
    
    const subscriptionLevels: Record<string, number> = {
      'starter': 1,
      'pro': 2,
      'enterprise': 3
    };
    
    const userLevel = subscriptionLevels[userSubscription] || 1;
    const requiredLevel = subscriptionLevels[pluginLevel] || 3;
    
    return userLevel >= requiredLevel;
  };

  const handleUpgradeClick = () => {
    toast.error('Upgrade to Pro or Enterprise to access this feature', {
      icon: '🔓',
      style: {
        borderRadius: '10px',
        background: '#333',
        color: '#fff',
      },
    });
  };

  const tabs = [
    { id: 'tariff', label: 'Tariff Calculator', icon: CreditCard, plugin: 'tariff' },
    { id: 'landed_cost', label: 'Landed Cost', icon: DollarSign, plugin: 'landed_cost' },
    { id: 'compliance', label: 'Compliance', icon: ShieldCheck, plugin: 'compliance' },
    { id: 'freight', label: 'Freight Estimator', icon: Truck, plugin: 'freight' },
    { id: 'tracker', label: 'Shipment Tracker', icon: Package, plugin: 'tracker' },
    { id: 'hs_finder', label: 'HS Code Finder', icon: Search, plugin: 'hs_finder' },
    { id: 'fta', label: 'FTA Checker', icon: FileCheck, plugin: 'fta' }
  ];

  if (isLoading) {
    return (
      <div className="p-4 lg:p-6 flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-signal-blue"></div>
      </div>
    );
  }

  const renderTabContent = () => {
    switch (activeTab) {
      case 'tariff':
        return <TariffCalculator />;
      case 'landed_cost':
        return <LandedCostEstimator />;
      case 'compliance':
        return <ComplianceChecker />;
      case 'freight':
        return <FreightEstimator />;
      case 'tracker':
        return <ShipmentTracker />;
      case 'hs_finder':
        return <HSCodeFinder />;
      case 'fta':
        return <FTAChecker />;
      default:
        return <TariffCalculator />;
    }
  };

  return (
    <div className="p-4 lg:p-6">
      <div className="mb-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Global Commerce</h2>
        <p className="text-gray-600">Manage international trade compliance and logistics</p>
      </div>

      {/* Tab Navigation */}
      <div className="border-b border-gray-200 mb-8">
        <nav className="flex space-x-4 lg:space-x-8 overflow-x-auto">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const hasAccess = checkAccess(tab.plugin);
            
            return (
              <button
                key={tab.id}
                onClick={() => hasAccess ? setActiveTab(tab.id) : handleUpgradeClick()}
                className={`flex items-center space-x-2 py-4 px-1 border-b-2 font-medium text-sm whitespace-nowrap relative group ${
                  !hasAccess 
                    ? 'border-transparent text-gray-400 cursor-not-allowed'
                    : activeTab === tab.id
                      ? 'border-signal-blue text-signal-blue'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <div className="flex items-center space-x-2">
                  <Icon className="w-4 h-4" />
                  <span>{tab.label}</span>
                  {!hasAccess && (
                    <span className="text-xs bg-red-100 text-red-600 px-1 rounded">
                      Pro
                    </span>
                  )}
                </div>
                {!hasAccess && (
                  <>
                    <Lock className="w-3 h-3 absolute top-3 right-0 text-red-400" />
                    <div className="absolute left-1/2 -translate-x-1/2 bottom-full mb-2 px-2 py-1 bg-red-600 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-10">
                      Upgrade to access
                    </div>
                  </>
                )}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Tab Content */}
      <div>
        {renderTabContent()}
      </div>
    </div>
  );
};

export default GlobalCommerceHub;