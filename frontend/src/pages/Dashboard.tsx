import React, { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  CircularProgress,
  Alert,
} from '@mui/material';
import {
  People,
  TrendingUp,
  Assignment,
  Chat,
} from '@mui/icons-material';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  LineChart,
  Line,
} from 'recharts';
import { dashboardService, DashboardStats } from '../services/api';

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

interface StatCardProps {
  title: string;
  value: number;
  icon: React.ReactNode;
  color: string;
}

const StatCard: React.FC<StatCardProps> = ({ title, value, icon, color }) => (
  <Card>
    <CardContent>
      <Box display="flex" alignItems="center" justifyContent="space-between">
        <Box>
          <Typography color="textSecondary" gutterBottom variant="body2">
            {title}
          </Typography>
          <Typography variant="h4" component="h2">
            {value}
          </Typography>
        </Box>
        <Box sx={{ color, fontSize: 40 }}>
          {icon}
        </Box>
      </Box>
    </CardContent>
  </Card>
);

const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const data = await dashboardService.getStats();
      setStats(data);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Errore nel caricamento dei dati');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return <Alert severity="error">{error}</Alert>;
  }

  if (!stats) {
    return <Alert severity="warning">Nessun dato disponibile</Alert>;
  }

  const opportunityStageData = stats.charts.opportunitiesByStage.map(item => ({
    name: item.stage,
    value: parseInt(item.count),
    totalValue: parseFloat(item.totalValue || 0),
  }));

  const activityTypeData = stats.charts.activitiesByType.map(item => ({
    name: item.type,
    value: parseInt(item.count),
  }));

  const customerTrendData = stats.charts.customerTrend.map(item => ({
    month: item.month,
    customers: parseInt(item.count),
  }));

  const salesPerformanceData = stats.charts.salesPerformance.map(item => ({
    month: item.month,
    count: parseInt(item.count),
    revenue: parseFloat(item.totalValue || 0),
  }));

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard
      </Typography>

      {/* Statistiche principali */}
      <Grid container spacing={3} mb={4}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Clienti Totali"
            value={stats.customers.total}
            icon={<People />}
            color="#2196f3"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Opportunità Aperte"
            value={stats.opportunities.open}
            icon={<TrendingUp />}
            color="#4caf50"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Attività Pendenti"
            value={stats.activities.pending}
            icon={<Assignment />}
            color="#ff9800"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Interazioni Settimana"
            value={stats.interactions.thisWeek}
            icon={<Chat />}
            color="#9c27b0"
          />
        </Grid>
      </Grid>

      {/* Grafici */}
      <Grid container spacing={3}>
        {/* Opportunità per stadio */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Opportunità per Stadio
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={opportunityStageData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, value }) => `${name}: ${value}`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {opportunityStageData.map((_, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>

        {/* Attività per tipo */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Attività per Tipo
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={activityTypeData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip />
                  <Bar dataKey="value" fill="#8884d8" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>

        {/* Trend clienti */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Trend Clienti (Ultimi 6 mesi)
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={customerTrendData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="month" />
                  <YAxis />
                  <Tooltip />
                  <Line 
                    type="monotone" 
                    dataKey="customers" 
                    stroke="#8884d8" 
                    strokeWidth={2}
                  />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>

        {/* Performance vendite */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Performance Vendite
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={salesPerformanceData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="month" />
                  <YAxis />
                  <Tooltip 
                    formatter={(value, name) => [
                      name === 'revenue' ? `€${value.toLocaleString()}` : value,
                      name === 'revenue' ? 'Fatturato' : 'Vendite'
                    ]}
                  />
                  <Bar dataKey="count" fill="#8884d8" name="count" />
                  <Bar dataKey="revenue" fill="#82ca9d" name="revenue" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Statistiche aggiuntive */}
      <Grid container spacing={3} mt={2}>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Riepilogo Clienti
              </Typography>
              <Box>
                <Typography variant="body2" color="text.secondary">
                  Clienti Attivi: {stats.customers.active}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Nuovi questo mese: {stats.customers.newThisMonth}
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Riepilogo Opportunità
              </Typography>
              <Box>
                <Typography variant="body2" color="text.secondary">
                  Valore totale: €{stats.opportunities.totalValue.toLocaleString()}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Opportunità vinte: {stats.opportunities.won}
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Riepilogo Attività
              </Typography>
              <Box>
                <Typography variant="body2" color="text.secondary">
                  Attività in scadenza: {stats.activities.overdue}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Totale attività: {stats.activities.total}
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;