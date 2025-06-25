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

interface User {
  id: number;
  firstName: string;
  lastName: string;
  email: string;
}

interface Interaction {
  id: number;
  type: string;
  subject: string;
  content: string;
  attachments?: string;
  createdAt: string;
  customer: Customer;
  customerId: number;
  user: User;
  userId: number;
}

const typeLabels: { [key: string]: string } = {
  call: 'Chiamata',
  email: 'Email',
  meeting: 'Riunione',
  note: 'Nota'
};

const typeColors: { [key: string]: 'default' | 'primary' | 'secondary' | 'error' | 'info' | 'success' | 'warning' } = {
  call: 'primary',
  email: 'info',
  meeting: 'warning',
  note: 'default'
};

const Interactions: React.FC = () => {
  const [interactions, setInteractions] = useState<Interaction[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [error, setError] = useState<string>('');
  const [open, setOpen] = useState(false);
  const [viewOpen, setViewOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [viewingInteraction, setViewingInteraction] = useState<Interaction | null>(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [typeFilter, setTypeFilter] = useState('');
  const [customerFilter, setCustomerFilter] = useState('');

  const [formData, setFormData] = useState({
    type: 'note',
    subject: '',
    content: '',
    attachments: '',
    customerId: ''
  });

  useEffect(() => {
    fetchInteractions();
    fetchCustomers();
  }, [page, typeFilter, customerFilter]);

  const fetchInteractions = async () => {
    try {
      const params = new URLSearchParams({
        page: page.toString(),
        limit: '10'
      });
      
      if (typeFilter) params.append('type', typeFilter);
      if (customerFilter) params.append('customerId', customerFilter);

      const response = await api.get(`/interactions?${params}`);
      setInteractions(response.data.interactions);
      setTotalPages(response.data.pagination.totalPages);
    } catch (err) {
      setError('Errore nel caricamento delle interazioni');
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
        customerId: parseInt(formData.customerId)
      };

      if (editingId) {
        await api.put(`/interactions/${editingId}`, submitData);
      } else {
        await api.post('/interactions', submitData);
      }
      
      setOpen(false);
      resetForm();
      fetchInteractions();
    } catch (err: any) {
      setError(err.response?.data?.message || 'Errore nel salvataggio');
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Sei sicuro di voler eliminare questa interazione?')) {
      try {
        await api.delete(`/interactions/${id}`);
        fetchInteractions();
      } catch (err: any) {
        setError(err.response?.data?.message || 'Errore nell\'eliminazione');
      }
    }
  };

  const handleEdit = (interaction: Interaction) => {
    setEditingId(interaction.id);
    setFormData({
      type: interaction.type,
      subject: interaction.subject,
      content: interaction.content,
      attachments: interaction.attachments || '',
      customerId: interaction.customerId.toString()
    });
    setOpen(true);
  };

  const handleView = (interaction: Interaction) => {
    setViewingInteraction(interaction);
    setViewOpen(true);
  };

  const resetForm = () => {
    setFormData({
      type: 'note',
      subject: '',
      content: '',
      attachments: '',
      customerId: ''
    });
    setEditingId(null);
  };

  const formatDateTime = (dateString: string) => {
    return new Date(dateString).toLocaleString('it-IT');
  };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" component="h1">
          Interazioni
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => {
            resetForm();
            setOpen(true);
          }}
        >
          Nuova Interazione
        </Button>
      </Box>

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2}>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Filtra per Tipo</InputLabel>
                <Select
                  value={typeFilter}
                  onChange={(e) => setTypeFilter(e.target.value)}
                  label="Filtra per Tipo"
                >
                  <MenuItem value="">Tutti</MenuItem>
                  {Object.entries(typeLabels).map(([value, label]) => (
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
              <TableCell>Tipo</TableCell>
              <TableCell>Oggetto</TableCell>
              <TableCell>Cliente</TableCell>
              <TableCell>Utente</TableCell>
              <TableCell>Data</TableCell>
              <TableCell>Azioni</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {interactions.map((interaction) => (
              <TableRow key={interaction.id}>
                <TableCell>
                  <Chip
                    label={typeLabels[interaction.type]}
                    color={typeColors[interaction.type]}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  <Typography variant="subtitle2">{interaction.subject}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {interaction.content.substring(0, 80)}...
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography variant="body2">{interaction.customer.name}</Typography>
                  {interaction.customer.company && (
                    <Typography variant="caption" color="text.secondary">
                      {interaction.customer.company}
                    </Typography>
                  )}
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {interaction.user.firstName} {interaction.user.lastName}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {interaction.user.email}
                  </Typography>
                </TableCell>
                <TableCell>{formatDateTime(interaction.createdAt)}</TableCell>
                <TableCell>
                  <IconButton onClick={() => handleView(interaction)} size="small">
                    <ViewIcon />
                  </IconButton>
                  <IconButton onClick={() => handleEdit(interaction)} size="small">
                    <EditIcon />
                  </IconButton>
                  <IconButton onClick={() => handleDelete(interaction.id)} size="small">
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
          {editingId ? 'Modifica Interazione' : 'Nuova Interazione'}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth required>
                <InputLabel>Tipo</InputLabel>
                <Select
                  value={formData.type}
                  onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                  label="Tipo"
                >
                  {Object.entries(typeLabels).map(([value, label]) => (
                    <MenuItem key={value} value={value}>{label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
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
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Oggetto"
                value={formData.subject}
                onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Contenuto"
                value={formData.content}
                onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                multiline
                rows={6}
                required
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Allegati (URL o note)"
                value={formData.attachments}
                onChange={(e) => setFormData({ ...formData, attachments: e.target.value })}
                helperText="Inserisci URL di file o note sugli allegati"
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

      {/* Dialog per visualizzazione */}
      <Dialog open={viewOpen} onClose={() => setViewOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          Dettagli Interazione
        </DialogTitle>
        <DialogContent>
          {viewingInteraction && (
            <Grid container spacing={2} sx={{ mt: 1 }}>
              <Grid item xs={12} md={6}>
                <Typography variant="subtitle2" gutterBottom>
                  Tipo
                </Typography>
                <Chip
                  label={typeLabels[viewingInteraction.type]}
                  color={typeColors[viewingInteraction.type]}
                  size="small"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="subtitle2" gutterBottom>
                  Data
                </Typography>
                <Typography variant="body2">
                  {formatDateTime(viewingInteraction.createdAt)}
                </Typography>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="subtitle2" gutterBottom>
                  Cliente
                </Typography>
                <Typography variant="body2">
                  {viewingInteraction.customer.name}
                  {viewingInteraction.customer.company && (
                    <span style={{ color: '#666' }}> ({viewingInteraction.customer.company})</span>
                  )}
                </Typography>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="subtitle2" gutterBottom>
                  Utente
                </Typography>
                <Typography variant="body2">
                  {viewingInteraction.user.firstName} {viewingInteraction.user.lastName}
                  <br />
                  <span style={{ color: '#666' }}>{viewingInteraction.user.email}</span>
                </Typography>
              </Grid>
              <Grid item xs={12}>
                <Typography variant="subtitle2" gutterBottom>
                  Oggetto
                </Typography>
                <Typography variant="body2">
                  {viewingInteraction.subject}
                </Typography>
              </Grid>
              <Grid item xs={12}>
                <Typography variant="subtitle2" gutterBottom>
                  Contenuto
                </Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                  {viewingInteraction.content}
                </Typography>
              </Grid>
              {viewingInteraction.attachments && (
                <Grid item xs={12}>
                  <Typography variant="subtitle2" gutterBottom>
                    Allegati
                  </Typography>
                  <Typography variant="body2">
                    {viewingInteraction.attachments}
                  </Typography>
                </Grid>
              )}
            </Grid>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setViewOpen(false)}>Chiudi</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Interactions;