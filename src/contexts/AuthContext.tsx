import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import { toast } from 'react-hot-toast';

// Define valid social providers
type SocialProvider = 'google' | 'facebook' | 'github';
type UserRole = 'admin' | 'manager' | 'specialist' | 'client';

interface User {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  avatar?: string;
  subscription?: 'starter' | 'growth' | 'pro';
  addOns?: string[];
}

interface AuthContextType {
  isAuthenticated: boolean;
  user: User | null;
  userType: 'agency' | 'client';
  currentClientId: string | null;
  login: (email: string, password: string, type: 'agency' | 'client') => Promise<void>;
  loginWithSocial: (provider: SocialProvider, type: 'agency' | 'client') => Promise<void>;
  logout: () => void;
  switchToClient: (clientId: string) => void;
  switchToAgency: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider = ({ children }: AuthProviderProps) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [userType, setUserType] = useState<'agency' | 'client'>('agency');
  const [currentClientId, setCurrentClientId] = useState<string | null>(null);

  useEffect(() => {
    // Check for existing session
    const savedUser = localStorage.getItem('b3acon_user');
    const savedUserType = localStorage.getItem('b3acon_user_type');

    if (savedUser && savedUserType) {
      setUser(JSON.parse(savedUser));
      setUserType(savedUserType as 'agency' | 'client');
      setIsAuthenticated(true);
    }

    // Set up Supabase auth listener
    const { data: { subscription } } = supabase ? supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (event === 'SIGNED_IN' && session) {
          // Get user profile from Supabase
          if (supabase) {
            const { data: profile } = await supabase
              .from('profiles')
              .select('*')
              .eq('id', session.user.id)
              .single();

            if (profile) {
              const userRole = profile.role as UserRole || 'client';
              
              const userData: User = {
                id: session.user.id,
                name: profile.full_name || session.user.email?.split('@')[0] || 'User',
                email: session.user.email || '',
                role: userRole,
                avatar: profile.avatar_url,
                subscription: profile.subscription || 'starter',
                addOns: profile.add_ons || []
              };

              setUser(userData);
              setUserType(userData.role === 'client' ? 'client' : 'agency');
              setIsAuthenticated(true);
              localStorage.setItem('b3acon_user', JSON.stringify(userData));
              localStorage.setItem('b3acon_user_type', userData.role === 'client' ? 'client' : 'agency');
            }
          }
        } else if (event === 'SIGNED_OUT') {
          setUser(null);
          setIsAuthenticated(false);
          setCurrentClientId(null);
          localStorage.removeItem('b3acon_user');
          localStorage.removeItem('b3acon_user_type');
        }
      }
    ) : { data: { subscription: null } };

    return () => {
      if (subscription) {
        subscription.unsubscribe();
      }
    };
  }, []);

  const login = async (email: string, password: string, type: 'agency' | 'client') => {
    try {
      // Demo mode - use mock users for authentication
      const mockUsers = {
        'sarah@sparkdigital.com': {
          id: '550e8400-e29b-41d4-a716-446655440001',
          name: 'Sarah Johnson',
          email: 'sarah@sparkdigital.com',
          role: 'admin' as UserRole,
          subscription: 'pro' as const,
          addOns: ['landing_page_builder', 'ai_assistant'],
          avatar: 'https://images.pexels.com/photos/3184360/pexels-photo-3184360.jpeg?auto=compress&cs=tinysrgb&w=40&h=40&fit=crop'
        },
        'john@techcorp.com': {
          id: '550e8400-e29b-41d4-a716-446655440002',
          name: 'John Smith',
          email: 'john@techcorp.com',
          role: 'client' as UserRole,
          subscription: 'growth' as const,
          addOns: ['landing_page_builder'],
          avatar: 'https://images.pexels.com/photos/3184360/pexels-photo-3184360.jpeg?auto=compress&cs=tinysrgb&w=40&h=40&fit=crop'
        },
        'demo@starter.com': {
          id: '550e8400-e29b-41d4-a716-446655440003',
          name: 'Demo Starter',
          email: 'demo@starter.com',
          role: 'client' as UserRole,
          subscription: 'starter' as const,
          addOns: [],
          avatar: 'https://images.pexels.com/photos/3184360/pexels-photo-3184360.jpeg?auto=compress&cs=tinysrgb&w=40&h=40&fit=crop'
        }
      };

      const mockUser = mockUsers[email as keyof typeof mockUsers];
      
      if (mockUser && password === 'password') {
        setUser(mockUser);
        setUserType(type);
        setIsAuthenticated(true);
        
        // Save to localStorage
        localStorage.setItem('b3acon_user', JSON.stringify(mockUser));
        localStorage.setItem('b3acon_user_type', type);
        toast.success(`Welcome back, ${mockUser.name}!`);
      } else {
        throw new Error('Invalid credentials. Use demo credentials: sarah@sparkdigital.com / password or john@techcorp.com / password');
      }
    } catch (error) {
      console.error('Login error:', error);
      toast.error(error instanceof Error ? error.message : 'Login failed');
      throw error;
    }
  };

  const loginWithSocial = async (provider: SocialProvider, type: 'agency' | 'client') => {
    if (!supabase) {
      throw new Error('Supabase not configured');
    }

    try {
      // For demo purposes, we'll use mock data since social auth requires proper setup
      const mockSocialUsers = {
        'google': {
          id: '550e8400-e29b-41d4-a716-446655440004',
          name: 'Google User',
          email: 'google@example.com',
          role: type === 'agency' ? 'admin' : 'client' as UserRole,
          subscription: 'growth' as const,
          addOns: ['landing_page_builder'],
          avatar: 'https://images.pexels.com/photos/3184360/pexels-photo-3184360.jpeg?auto=compress&cs=tinysrgb&w=40&h=40&fit=crop'
        },
        'facebook': {
          id: '550e8400-e29b-41d4-a716-446655440005',
          name: 'Facebook User',
          email: 'facebook@example.com',
          role: type === 'agency' ? 'admin' : 'client' as UserRole,
          subscription: 'pro' as const,
          addOns: ['landing_page_builder', 'ai_assistant'],
          avatar: 'https://images.pexels.com/photos/3184360/pexels-photo-3184360.jpeg?auto=compress&cs=tinysrgb&w=40&h=40&fit=crop'
        },
        'github': {
          id: '550e8400-e29b-41d4-a716-446655440006',
          name: 'GitHub User',
          email: 'github@example.com',
          role: type === 'agency' ? 'admin' : 'client' as UserRole,
          subscription: 'starter' as const,
          addOns: [],
          avatar: 'https://images.pexels.com/photos/3184360/pexels-photo-3184360.jpeg?auto=compress&cs=tinysrgb&w=40&h=40&fit=crop'
        }
      };

      const mockUser = mockSocialUsers[provider];
      setUser(mockUser);
      setUserType(type);
      setIsAuthenticated(true);
      
      // Save to localStorage
      localStorage.setItem('b3acon_user', JSON.stringify(mockUser));
      localStorage.setItem('b3acon_user_type', type);

      // In a real implementation, we would use Supabase social auth:
      // const { data, error } = await supabase.auth.signInWithOAuth({
      //   provider: provider,
      //   options: {
      //     redirectTo: `${window.location.origin}/auth/callback`
      //   }
      // });
      
      // if (error) throw error;
    } catch (error) {
      console.error(`${provider} login failed:`, error);
      throw error;
    }
  };

  const logout = () => {
    if (supabase) {
      supabase.auth.signOut();
      toast.success('Logged out successfully');
    }
    setUser(null);
    setIsAuthenticated(false);
    setCurrentClientId(null);
    localStorage.removeItem('b3acon_user');
    localStorage.removeItem('b3acon_user_type');
    window.location.href = '/';
  };

  const switchToClient = (clientId: string) => {
    setCurrentClientId(clientId);
    setUserType('client');
    toast.success('Switched to client view');
  };

  const switchToAgency = () => {
    setCurrentClientId(null);
    setUserType('agency');
    toast.success('Switched to agency view');
  };

  const value: AuthContextType = {
    isAuthenticated,
    user,
    userType,
    currentClientId,
    login,
    loginWithSocial,
    logout,
    switchToClient,
    switchToAgency,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};