import axios from 'axios';

// Fix: usa il proxy Vite invece di localhost diretto
const API_BASE_URL = '/api'; // Usa il proxy Vite invece di URL assoluto

// Configurazione axios
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor per aggiungere token di autenticazione
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Interceptor per gestire errori di autenticazione
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
export { api };

// Tipi TypeScript
export interface User {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  createdAt?: string;
}

export interface Customer {
  id?: number;
  name: string;
  company?: string;
  industry?: string;
  email?: string;
  phone?: string;
  address?: string;
  city?: string;
  country?: string;
  status: 'prospect' | 'active' | 'inactive' | 'lost';
  notes?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface Opportunity {
  id?: number;
  title: string;
  description?: string;
  value: number;
  probability: number;
  stage: 'prospect' | 'qualified' | 'proposal' | 'negotiation' | 'closed_won' | 'closed_lost';
  expectedCloseDate?: string;
  actualCloseDate?: string;
  customerId: number;
  customer?: Customer;
  createdAt?: string;
  updatedAt?: string;
}

export interface Activity {
  id?: number;
  title: string;
  description?: string;
  type: 'call' | 'email' | 'meeting' | 'followup' | 'task';
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled';
  dueDate: string;
  completedDate?: string;
  priority: 1 | 2 | 3;
  assignedToId: number;
  assignedTo?: User;
  createdAt?: string;
  updatedAt?: string;
}

export interface Interaction {
  id?: number;
  type: 'call' | 'email' | 'meeting' | 'note';
  subject: string;
  content: string;
  attachments?: string;
  customerId: number;
  customer?: Customer;
  userId: number;
  user?: User;
  createdAt?: string;
}

export interface DashboardStats {
  customers: {
    total: number;
    active: number;
    newThisMonth: number;
  };
  opportunities: {
    total: number;
    open: number;
    totalValue: number;
    won: number;
  };
  activities: {
    total: number;
    pending: number;
    overdue: number;
  };
  interactions: {
    total: number;
    thisWeek: number;
  };
  charts: {
    opportunitiesByStage: any[];
    activitiesByType: any[];
    customerTrend: any[];
    salesPerformance: any[];
  };
}

// Servizi API
export const authService = {
  login: async (email: string, password: string) => {
    const response = await api.post('/auth/login', { email, password });
    return response.data;
  },

  register: async (userData: Partial<User> & { password: string }) => {
    const response = await api.post('/auth/register', userData);
    return response.data;
  },

  getProfile: async () => {
    const response = await api.get('/auth/profile');
    return response.data;
  },
};

export const customerService = {
  getAll: async (params?: any) => {
    const response = await api.get('/customers', { params });
    return response.data;
  },

  getById: async (id: number) => {
    const response = await api.get(`/customers/${id}`);
    return response.data;
  },

  create: async (customer: Customer) => {
    const response = await api.post('/customers', customer);
    return response.data;
  },

  update: async (id: number, customer: Partial<Customer>) => {
    const response = await api.put(`/customers/${id}`, customer);
    return response.data;
  },

  delete: async (id: number) => {
    const response = await api.delete(`/customers/${id}`);
    return response.data;
  },

  getStats: async () => {
    const response = await api.get('/customers/stats');
    return response.data;
  },
};

export const opportunityService = {
  getAll: async (params?: any) => {
    const response = await api.get('/opportunities', { params });
    return response.data;
  },

  getById: async (id: number) => {
    const response = await api.get(`/opportunities/${id}`);
    return response.data;
  },

  create: async (opportunity: Opportunity) => {
    const response = await api.post('/opportunities', opportunity);
    return response.data;
  },

  update: async (id: number, opportunity: Partial<Opportunity>) => {
    const response = await api.put(`/opportunities/${id}`, opportunity);
    return response.data;
  },

  delete: async (id: number) => {
    const response = await api.delete(`/opportunities/${id}`);
    return response.data;
  },

  getStats: async () => {
    const response = await api.get('/opportunities/stats');
    return response.data;
  },
};

export const activityService = {
  getAll: async (params?: any) => {
    const response = await api.get('/activities', { params });
    return response.data;
  },

  getById: async (id: number) => {
    const response = await api.get(`/activities/${id}`);
    return response.data;
  },

  create: async (activity: Activity) => {
    const response = await api.post('/activities', activity);
    return response.data;
  },

  update: async (id: number, activity: Partial<Activity>) => {
    const response = await api.put(`/activities/${id}`, activity);
    return response.data;
  },

  delete: async (id: number) => {
    const response = await api.delete(`/activities/${id}`);
    return response.data;
  },

  getMyActivities: async (params?: any) => {
    const response = await api.get('/activities/my-activities', { params });
    return response.data;
  },

  getUpcoming: async () => {
    const response = await api.get('/activities/upcoming');
    return response.data;
  },
};

export const interactionService = {
  getAll: async (params?: any) => {
    const response = await api.get('/interactions', { params });
    return response.data;
  },

  getById: async (id: number) => {
    const response = await api.get(`/interactions/${id}`);
    return response.data;
  },

  create: async (interaction: Interaction) => {
    const response = await api.post('/interactions', interaction);
    return response.data;
  },

  update: async (id: number, interaction: Partial<Interaction>) => {
    const response = await api.put(`/interactions/${id}`, interaction);
    return response.data;
  },

  delete: async (id: number) => {
    const response = await api.delete(`/interactions/${id}`);
    return response.data;
  },

  getByCustomer: async (customerId: number) => {
    const response = await api.get(`/interactions/customer/${customerId}`);
    return response.data;
  },

  getRecent: async (limit?: number) => {
    const response = await api.get('/interactions/recent', { 
      params: limit ? { limit } : {} 
    });
    return response.data;
  },
};

export const dashboardService = {
  getStats: async (): Promise<DashboardStats> => {
    const response = await api.get('/dashboard/stats');
    return response.data;
  },

  getReports: async (params: any) => {
    const response = await api.get('/dashboard/reports', { params });
    return response.data;
  },
};