import React, { useState, useEffect } from 'react';
import {
  Box,
  Button,
  Card,
  CardContent,
  Typography,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  MenuItem,
  Alert,
  Chip,
  Tooltip,
} from '@mui/material';
import {
  DataGrid,
  GridColDef,
  GridActionsCellItem,
  GridRowParams,
} from '@mui/x-data-grid';
import {
  Add,
  Edit,
  Delete,
  Search,
  Visibility,
} from '@mui/icons-material';
import { useForm, Controller } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { Customer, customerService } from '../services/api';

// Schema Yup corretto - solo nome e status obbligatori
const schema = yup.object({
  name: yup.string().required('Nome richiesto'),
  company: yup.string().nullable(),
  industry: yup.string().nullable(),
  email: yup.string().email('Email non valida').nullable(),
  phone: yup.string().nullable(),
  address: yup.string().nullable(),
  city: yup.string().nullable(),
  country: yup.string().nullable(),
  status: yup.string().required('Status richiesto'),
  notes: yup.string().nullable(),
});

const statusOptions = [
  { value: 'prospect', label: 'Prospect', color: 'info' },
  { value: 'active', label: 'Attivo', color: 'success' },
  { value: 'inactive', label: 'Inattivo', color: 'warning' },
  { value: 'lost', label: 'Perso', color: 'error' },
] as const;

const Customers: React.FC = () => {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);
  const [viewOpen, setViewOpen] = useState(false);
  const [editingCustomer, setEditingCustomer] = useState<Customer | null>(null);
  const [viewingCustomer, setViewingCustomer] = useState<Customer | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const {
    control,
    handleSubmit,
    reset,
    formState: { errors, isValid },
  } = useForm<Customer>({
    resolver: yupResolver(schema) as any,
    mode: 'onChange', // Validazione real-time
    defaultValues: {
      status: 'prospect',
    },
  });

  useEffect(() => {
    loadCustomers();
  }, [searchTerm, statusFilter]);

  const loadCustomers = async () => {
    try {
      setLoading(true);
      const params: any = {};
      if (searchTerm) params.search = searchTerm;
      if (statusFilter) params.status = statusFilter;
      
      const response = await customerService.getAll(params);
      setCustomers(response.customers || response);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Errore nel caricamento clienti');
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = (customer?: Customer) => {
    setEditingCustomer(customer || null);
    if (customer) {
      // Reset con i valori del customer per modifica
      reset({
        name: customer.name || '',
        company: customer.company || '',
        industry: customer.industry || '',
        email: customer.email || '',
        phone: customer.phone || '',
        address: customer.address || '',
        city: customer.city || '',
        country: customer.country || '',
        status: customer.status || 'prospect',
        notes: customer.notes || ''
      });
    } else {
      // Reset per nuovo customer
      reset({
        name: '',
        company: '',
        industry: '',
        email: '',
        phone: '',
        address: '',
        city: '',
        country: '',
        status: 'prospect',
        notes: ''
      });
    }
    setOpen(true);
  };

  const handleCloseDialog = () => {
    setOpen(false);
    setEditingCustomer(null);
    reset();
  };

  const onSubmit = async (data: Customer) => {
    try {
      // Pulisci campi vuoti (trasforma stringhe vuote in null)
      const cleanedData = Object.keys(data).reduce((acc, key) => {
        const value = data[key as keyof Customer];
        acc[key as keyof Customer] = value === '' ? null : value;
        return acc;
      }, {} as any);

      if (editingCustomer) {
        await customerService.update(editingCustomer.id!, cleanedData);
      } else {
        await customerService.create(cleanedData);
      }
      
      handleCloseDialog();
      loadCustomers();
    } catch (err: any) {
      setError(err.response?.data?.message || 'Errore nel salvataggio cliente');
    }
  };

  const handleDelete = async (id: number) => {
    try {
      await customerService.delete(id);
      loadCustomers();
    } catch (err: any) {
      // Gestione errori specifici per dipendenze
      if (err.response?.status === 409) {
        const errorData = err.response.data;
        const dependencyMessage = `
Impossibile eliminare il cliente "${errorData.details?.customerName}".

Il cliente ha i seguenti dati collegati:
• ${errorData.dependencies}

${errorData.suggestion}
        `.trim();
        
        setError(dependencyMessage);
      } else {
        setError(err.response?.data?.message || 'Errore nell\'eliminazione cliente');
      }
    }
  };

  const confirmDelete = (customer: Customer) => {
    const message = `Sei sicuro di voler eliminare il cliente "${customer.name}"?`;
    if (window.confirm(message)) {
      handleDelete(customer.id!);
    }
  };

  const handleView = (customer: Customer) => {
    setViewingCustomer(customer);
    setViewOpen(true);
  };

  const getStatusColor = (status: string) => {
    const statusOption = statusOptions.find(opt => opt.value === status);
    return statusOption?.color || 'default';
  };

  const getStatusLabel = (status: string) => {
    const statusOption = statusOptions.find(opt => opt.value === status);
    return statusOption?.label || status;
  };

  const columns: GridColDef[] = [
    { 
      field: 'name', 
      headerName: 'Nome', 
      width: 200,
      renderCell: (params) => (
        <Box>
          <Typography variant="body2" fontWeight="bold">
            {params.value}
          </Typography>
          {params.row.company && (
            <Typography variant="caption" color="text.secondary">
              {params.row.company}
            </Typography>
          )}
        </Box>
      ),
    },
    { field: 'email', headerName: 'Email', width: 200 },
    { field: 'phone', headerName: 'Telefono', width: 150 },
    { field: 'industry', headerName: 'Settore', width: 150 },
    { 
      field: 'status', 
      headerName: 'Status', 
      width: 120,
      renderCell: (params) => (
        <Chip
          label={getStatusLabel(params.value)}
          color={getStatusColor(params.value) as any}
          size="small"
        />
      ),
    },
    {
      field: 'actions',
      type: 'actions',
      headerName: 'Azioni',
      width: 120,
      getActions: (params: GridRowParams) => [
        <GridActionsCellItem
          icon={
            <Tooltip title="Visualizza">
              <Visibility />
            </Tooltip>
          }
          label="Visualizza"
          onClick={() => handleView(params.row)}
        />,
        <GridActionsCellItem
          icon={
            <Tooltip title="Modifica">
              <Edit />
            </Tooltip>
          }
          label="Modifica"
          onClick={() => handleOpenDialog(params.row)}
        />,
        <GridActionsCellItem
          icon={
            <Tooltip title="Elimina">
              <Delete />
            </Tooltip>
          }
          label="Elimina"
          onClick={() => confirmDelete(params.row)}
        />,
      ],
    },
  ];

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Clienti</Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => handleOpenDialog()}
        >
          Nuovo Cliente
        </Button>
      </Box>

      {error && (
        <Alert 
          severity="error" 
          sx={{ 
            mb: 2,
            whiteSpace: 'pre-line' // Permette line breaks nel messaggio 
          }} 
          onClose={() => setError('')}
        >
          {error}
        </Alert>
      )}

      {/* Filtri */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" gap={2} flexWrap="wrap">
            <TextField
              label="Cerca clienti"
              variant="outlined"
              size="small"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              InputProps={{
                startAdornment: <Search color="action" />,
              }}
              sx={{ minWidth: 250 }}
            />
            <TextField
              label="Filtra per status"
              select
              variant="outlined"
              size="small"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              sx={{ minWidth: 150 }}
            >
              <MenuItem value="">Tutti</MenuItem>
              {statusOptions.map((option) => (
                <MenuItem key={option.value} value={option.value}>
                  {option.label}
                </MenuItem>
              ))}
            </TextField>
          </Box>
        </CardContent>
      </Card>

      {/* Tabella clienti */}
      <Card>
        <DataGrid
          rows={customers}
          columns={columns}
          loading={loading}
          pageSizeOptions={[10, 25, 50]}
          initialState={{
            pagination: { paginationModel: { pageSize: 10 } },
          }}
          autoHeight
          disableRowSelectionOnClick
        />
      </Card>

      {/* Dialog per aggiungere/modificare cliente */}
      <Dialog open={open} onClose={handleCloseDialog} maxWidth="md" fullWidth>
        <form onSubmit={handleSubmit(onSubmit)}>
          <DialogTitle>
            {editingCustomer ? 'Modifica Cliente' : 'Nuovo Cliente'}
          </DialogTitle>
          <DialogContent>
            <Box sx={{ pt: 1 }}>
              <Controller
                name="name"
                control={control}
                render={({ field }) => (
                  <TextField
                    {...field}
                    label="Nome *"
                    fullWidth
                    margin="normal"
                    error={!!errors.name}
                    helperText={errors.name?.message}
                  />
                )}
              />

              <Controller
                name="company"
                control={control}
                render={({ field }) => (
                  <TextField
                    {...field}
                    label="Azienda"
                    fullWidth
                    margin="normal"
                  />
                )}
              />

              <Controller
                name="industry"
                control={control}
                render={({ field }) => (
                  <TextField
                    {...field}
                    label="Settore"
                    fullWidth
                    margin="normal"
                  />
                )}
              />

              <Box display="flex" gap={2}>
                <Controller
                  name="email"
                  control={control}
                  render={({ field }) => (
                    <TextField
                      {...field}
                      label="Email"
                      type="email"
                      fullWidth
                      margin="normal"
                      error={!!errors.email}
                      helperText={errors.email?.message}
                    />
                  )}
                />

                <Controller
                  name="phone"
                  control={control}
                  render={({ field }) => (
                    <TextField
                      {...field}
                      label="Telefono"
                      fullWidth
                      margin="normal"
                    />
                  )}
                />
              </Box>

              <Controller
                name="address"
                control={control}
                render={({ field }) => (
                  <TextField
                    {...field}
                    label="Indirizzo"
                    fullWidth
                    margin="normal"
                  />
                )}
              />

              <Box display="flex" gap={2}>
                <Controller
                  name="city"
                  control={control}
                  render={({ field }) => (
                    <TextField
                      {...field}
                      label="Città"
                      fullWidth
                      margin="normal"
                    />
                  )}
                />

                <Controller
                  name="country"
                  control={control}
                  render={({ field }) => (
                    <TextField
                      {...field}
                      label="Paese"
                      fullWidth
                      margin="normal"
                    />
                  )}
                />
              </Box>

              <Controller
                name="status"
                control={control}
                render={({ field }) => (
                  <TextField
                    {...field}
                    label="Status *"
                    select
                    fullWidth
                    margin="normal"
                    error={!!errors.status}
                    helperText={errors.status?.message}
                  >
                    {statusOptions.map((option) => (
                      <MenuItem key={option.value} value={option.value}>
                        {option.label}
                      </MenuItem>
                    ))}
                  </TextField>
                )}
              />

              <Controller
                name="notes"
                control={control}
                render={({ field }) => (
                  <TextField
                    {...field}
                    label="Note"
                    multiline
                    rows={3}
                    fullWidth
                    margin="normal"
                  />
                )}
              />
            </Box>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleCloseDialog}>Annulla</Button>
            <Button 
              type="submit" 
              variant="contained"
              disabled={!isValid}
            >
              {editingCustomer ? 'Aggiorna' : 'Crea'}
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      {/* Dialog per visualizzazione dettagli cliente */}
      <Dialog open={viewOpen} onClose={() => setViewOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          Dettagli Cliente
        </DialogTitle>
        <DialogContent>
          {viewingCustomer && (
            <Box sx={{ pt: 2 }}>
              <Typography variant="h6" gutterBottom>
                {viewingCustomer.name}
                {viewingCustomer.company && (
                  <Typography variant="subtitle1" color="text.secondary" component="span">
                    {' - '}{viewingCustomer.company}
                  </Typography>
                )}
              </Typography>
              
              <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 2, mt: 2 }}>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Email</Typography>
                  <Typography variant="body1">{viewingCustomer.email || 'Non specificato'}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Telefono</Typography>
                  <Typography variant="body1">{viewingCustomer.phone || 'Non specificato'}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Settore</Typography>
                  <Typography variant="body1">{viewingCustomer.industry || 'Non specificato'}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Status</Typography>
                  <Chip
                    label={getStatusLabel(viewingCustomer.status)}
                    color={getStatusColor(viewingCustomer.status) as any}
                    size="small"
                  />
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Città</Typography>
                  <Typography variant="body1">{viewingCustomer.city || 'Non specificato'}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Paese</Typography>
                  <Typography variant="body1">{viewingCustomer.country || 'Non specificato'}</Typography>
                </Box>
              </Box>
              
              {viewingCustomer.address && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" color="text.secondary">Indirizzo</Typography>
                  <Typography variant="body1">{viewingCustomer.address}</Typography>
                </Box>
              )}
              
              {viewingCustomer.notes && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" color="text.secondary">Note</Typography>
                  <Typography variant="body1" sx={{ whiteSpace: 'pre-wrap' }}>
                    {viewingCustomer.notes}
                  </Typography>
                </Box>
              )}
              
              {viewingCustomer.createdAt && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" color="text.secondary">Data creazione</Typography>
                  <Typography variant="body1">
                    {new Date(viewingCustomer.createdAt).toLocaleDateString('it-IT')}
                  </Typography>
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
              handleOpenDialog(viewingCustomer!);
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

export default Customers;