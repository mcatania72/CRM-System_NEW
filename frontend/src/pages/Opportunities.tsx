import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  Grid,
  Alert,
  Pagination
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Visibility as ViewIcon
} from '@mui/icons-material';
import { api } from '../services/api';

interface Customer {
  id: number;
  name: string;
  company?: string;
}

interface Opportunity {
  id: number;
  title: string;
  description?: string;
  value: number;
  probability: number;
  stage: string;
  expectedCloseDate?: string;
  actualCloseDate?: string;
  createdAt: string;
  customer: Customer;
  customerId: number;
}

const stageColors: { [key: string]: 'default' | 'primary' | 'secondary' | 'error' | 'info' | 'success' | 'warning' } = {
  prospect: 'default',
  qualified: 'info',
  proposal: 'primary',
  negotiation: 'warning',
  closed_won: 'success',
  closed_lost: 'error'
};

const stageLabels: { [key: string]: string } = {
  prospect: 'Prospect',
  qualified: 'Qualificato',
  proposal: 'Proposta',
  negotiation: 'Negoziazione',
  closed_won: 'Chiuso Vinto',
  closed_lost: 'Chiuso Perso'
};

const Opportunities: React.FC = () => {
  const [opportunities, setOpportunities] = useState<Opportunity[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [error, setError] = useState<string>('');
  const [open, setOpen] = useState(false);
  const [viewOpen, setViewOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [viewingOpportunity, setViewingOpportunity] = useState<Opportunity | null>(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [stageFilter, setStageFilter] = useState('');
  const [customerFilter, setCustomerFilter] = useState('');

  const [formData, setFormData] = useState({
    title: '',
    description: '',
    value: '',
    probability: '0',
    stage: 'prospect',
    expectedCloseDate: '',
    customerId: ''
  });

  useEffect(() => {
    fetchOpportunities();
    fetchCustomers();
  }, [page, stageFilter, customerFilter]);

  const fetchOpportunities = async () => {
    try {
      const params = new URLSearchParams({
        page: page.toString(),
        limit: '10'
      });
      
      if (stageFilter) params.append('stage', stageFilter);
      if (customerFilter) params.append('customerId', customerFilter);

      const response = await api.get(`/opportunities?${params}`);
      setOpportunities(response.data.opportunities);
      setTotalPages(response.data.pagination.totalPages);
    } catch (err) {
      setError('Errore nel caricamento delle opportunità');
      console.error(err);
    }
  };

  const fetchCustomers = async () => {
    try {
      const response = await api.get('/customers?limit=100');
      setCustomers(response.data.customers);
    } catch (err) {
      console.error('Errore nel caricamento clienti:', err);
    }
  };

  const handleSubmit = async () => {
    try {
      const submitData = {
        ...formData,
        value: parseFloat(formData.value),
        probability: parseInt(formData.probability),
        customerId: parseInt(formData.customerId),
        expectedCloseDate: formData.expectedCloseDate || null
      };

      if (editingId) {
        await api.put(`/opportunities/${editingId}`, submitData);
      } else {
        await api.post('/opportunities', submitData);
      }
      
      setOpen(false);
      resetForm();
      fetchOpportunities();
    } catch (err: any) {
      setError(err.response?.data?.message || 'Errore nel salvataggio');
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Sei sicuro di voler eliminare questa opportunità?')) {
      try {
        await api.delete(`/opportunities/${id}`);
        fetchOpportunities();
      } catch (err: any) {
        setError(err.response?.data?.message || 'Errore nell\'eliminazione');
      }
    }
  };

  const handleEdit = (opportunity: Opportunity) => {
    setEditingId(opportunity.id);
    setFormData({
      title: opportunity.title,
      description: opportunity.description || '',
      value: opportunity.value.toString(),
      probability: opportunity.probability.toString(),
      stage: opportunity.stage,
      expectedCloseDate: opportunity.expectedCloseDate ? opportunity.expectedCloseDate.split('T')[0] : '',
      customerId: opportunity.customerId.toString()
    });
    setOpen(true);
  };

  const handleView = (opportunity: Opportunity) => {
    setViewingOpportunity(opportunity);
    setViewOpen(true);
  };

  const resetForm = () => {
    setFormData({
      title: '',
      description: '',
      value: '',
      probability: '0',
      stage: 'prospect',
      expectedCloseDate: '',
      customerId: ''
    });
    setEditingId(null);
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('it-IT', {
      style: 'currency',
      currency: 'EUR'
    }).format(value);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('it-IT');
  };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" component="h1">
          Opportunità
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => {
            resetForm();
            setOpen(true);
          }}
        >
          Nuova Opportunità
        </Button>
      </Box>

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2}>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Filtra per Stadio</InputLabel>
                <Select
                  value={stageFilter}
                  onChange={(e) => setStageFilter(e.target.value)}
                  label="Filtra per Stadio"
                >
                  <MenuItem value="">Tutti</MenuItem>
                  {Object.entries(stageLabels).map(([value, label]) => (
                    <MenuItem key={value} value={value}>{label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Filtra per Cliente</InputLabel>
                <Select
                  value={customerFilter}
                  onChange={(e) => setCustomerFilter(e.target.value)}
                  label="Filtra per Cliente"
                >
                  <MenuItem value="">Tutti</MenuItem>
                  {customers.map((customer) => (
                    <MenuItem key={customer.id} value={customer.id.toString()}>
                      {customer.name} {customer.company && `(${customer.company})`}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Titolo</TableCell>
              <TableCell>Cliente</TableCell>
              <TableCell>Valore</TableCell>
              <TableCell>Probabilità</TableCell>
              <TableCell>Stadio</TableCell>
              <TableCell>Data Prevista</TableCell>
              <TableCell>Creata</TableCell>
              <TableCell>Azioni</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {opportunities.map((opportunity) => (
              <TableRow key={opportunity.id}>
                <TableCell>
                  <Typography variant="subtitle2">{opportunity.title}</Typography>
                  {opportunity.description && (
                    <Typography variant="body2" color="text.secondary">
                      {opportunity.description.substring(0, 50)}...
                    </Typography>
                  )}
                </TableCell>
                <TableCell>
                  <Typography variant="body2">{opportunity.customer.name}</Typography>
                  {opportunity.customer.company && (
                    <Typography variant="caption" color="text.secondary">
                      {opportunity.customer.company}
                    </Typography>
                  )}
                </TableCell>
                <TableCell>{formatCurrency(opportunity.value)}</TableCell>
                <TableCell>{opportunity.probability}%</TableCell>
                <TableCell>
                  <Chip
                    label={stageLabels[opportunity.stage]}
                    color={stageColors[opportunity.stage]}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  {opportunity.expectedCloseDate && formatDate(opportunity.expectedCloseDate)}
                </TableCell>
                <TableCell>{formatDate(opportunity.createdAt)}</TableCell>
                <TableCell>
                  <IconButton onClick={() => handleView(opportunity)} size="small">
                    <ViewIcon />
                  </IconButton>
                  <IconButton onClick={() => handleEdit(opportunity)} size="small">
                    <EditIcon />
                  </IconButton>
                  <IconButton onClick={() => handleDelete(opportunity.id)} size="small">
                    <DeleteIcon />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 3 }}>
        <Pagination
          count={totalPages}
          page={page}
          onChange={(_, value) => setPage(value)}
          color="primary"
        />
      </Box>

      {/* Dialog per creazione/modifica */}
      <Dialog open={open} onClose={() => setOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingId ? 'Modifica Opportunità' : 'Nuova Opportunità'}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Titolo"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Descrizione"
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                multiline
                rows={3}
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Valore (€)"
                type="number"
                value={formData.value}
                onChange={(e) => setFormData({ ...formData, value: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Probabilità (%)"
                type="number"
                value={formData.probability}
                onChange={(e) => setFormData({ ...formData, probability: e.target.value })}
                inputProps={{ min: 0, max: 100 }}
                required
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth required>
                <InputLabel>Cliente</InputLabel>
                <Select
                  value={formData.customerId}
                  onChange={(e) => setFormData({ ...formData, customerId: e.target.value })}
                  label="Cliente"
                >
                  {customers.map((customer) => (
                    <MenuItem key={customer.id} value={customer.id.toString()}>
                      {customer.name} {customer.company && `(${customer.company})`}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth required>
                <InputLabel>Stadio</InputLabel>
                <Select
                  value={formData.stage}
                  onChange={(e) => setFormData({ ...formData, stage: e.target.value })}
                  label="Stadio"
                >
                  {Object.entries(stageLabels).map(([value, label]) => (
                    <MenuItem key={value} value={value}>{label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Data Prevista Chiusura"
                type="date"
                value={formData.expectedCloseDate}
                onChange={(e) => setFormData({ ...formData, expectedCloseDate: e.target.value })}
                InputLabelProps={{ shrink: true }}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Annulla</Button>
          <Button onClick={handleSubmit} variant="contained">
            {editingId ? 'Aggiorna' : 'Crea'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog per visualizzazione dettagli opportunità */}
      <Dialog open={viewOpen} onClose={() => setViewOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          Dettagli Opportunità
        </DialogTitle>
        <DialogContent>
          {viewingOpportunity && (
            <Box sx={{ pt: 2 }}>
              <Typography variant="h6" gutterBottom>
                {viewingOpportunity.title}
              </Typography>
              
              <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 2, mt: 2 }}>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Cliente</Typography>
                  <Typography variant="body1">
                    {viewingOpportunity.customer.name}
                    {viewingOpportunity.customer.company && (
                      <Typography variant="caption" color="text.secondary" component="span">
                        {' - '}{viewingOpportunity.customer.company}
                      </Typography>
                    )}
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Valore</Typography>
                  <Typography variant="body1">{formatCurrency(viewingOpportunity.value)}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Probabilità</Typography>
                  <Typography variant="body1">{viewingOpportunity.probability}%</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Stadio</Typography>
                  <Chip
                    label={stageLabels[viewingOpportunity.stage]}
                    color={stageColors[viewingOpportunity.stage]}
                    size="small"
                  />
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Data Prevista</Typography>
                  <Typography variant="body1">
                    {viewingOpportunity.expectedCloseDate ? formatDate(viewingOpportunity.expectedCloseDate) : 'Non specificata'}
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Data Creazione</Typography>
                  <Typography variant="body1">{formatDate(viewingOpportunity.createdAt)}</Typography>
                </Box>
              </Box>
              
              {viewingOpportunity.description && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" color="text.secondary">Descrizione</Typography>
                  <Typography variant="body1" sx={{ whiteSpace: 'pre-wrap' }}>
                    {viewingOpportunity.description}
                  </Typography>
                </Box>
              )}
              
              {viewingOpportunity.actualCloseDate && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" color="text.secondary">Data Chiusura Effettiva</Typography>
                  <Typography variant="body1">{formatDate(viewingOpportunity.actualCloseDate)}</Typography>
                </Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setViewOpen(false)}>Chiudi</Button>
          <Button 
            onClick={() => {
              setViewOpen(false);
              handleEdit(viewingOpportunity!);
            }} 
            variant="contained"
          >
            Modifica
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Opportunities;