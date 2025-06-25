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
  Check as CheckIcon,
  PlayArrow as StartIcon,
  Visibility as ViewIcon
} from '@mui/icons-material';
import { api } from '../services/api';

interface User {
  id: number;
  firstName: string;
  lastName: string;
  email: string;
}

interface Activity {
  id: number;
  title: string;
  description?: string;
  type: string;
  status: string;
  dueDate: string;
  completedDate?: string;
  priority: number;
  createdAt: string;
  assignedTo: User;
  assignedToId: number;
}

const typeLabels: { [key: string]: string } = {
  call: 'Chiamata',
  email: 'Email',
  meeting: 'Riunione',
  followup: 'Follow-up',
  task: 'Attività'
};

const statusLabels: { [key: string]: string } = {
  pending: 'In Attesa',
  in_progress: 'In Corso',
  completed: 'Completata',
  cancelled: 'Annullata'
};

const statusColors: { [key: string]: 'default' | 'primary' | 'secondary' | 'error' | 'info' | 'success' | 'warning' } = {
  pending: 'default',
  in_progress: 'info',
  completed: 'success',
  cancelled: 'error'
};

const priorityLabels: { [key: number]: string } = {
  1: 'Bassa',
  2: 'Media',
  3: 'Alta'
};

const priorityColors: { [key: number]: 'default' | 'primary' | 'secondary' | 'error' | 'info' | 'success' | 'warning' } = {
  1: 'default',
  2: 'warning',
  3: 'error'
};

const Activities: React.FC = () => {
  const [activities, setActivities] = useState<Activity[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [error, setError] = useState<string>('');
  const [open, setOpen] = useState(false);
  const [viewOpen, setViewOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [viewingActivity, setViewingActivity] = useState<Activity | null>(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [statusFilter, setStatusFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState('');

  const [formData, setFormData] = useState({
    title: '',
    description: '',
    type: 'task',
    status: 'pending',
    dueDate: '',
    priority: '2',
    assignedToId: ''
  });

  useEffect(() => {
    fetchActivities();
    fetchUsers();
  }, [page, statusFilter, typeFilter]);

  const fetchActivities = async () => {
    try {
      const params = new URLSearchParams({
        page: page.toString(),
        limit: '10'
      });
      
      if (statusFilter) params.append('status', statusFilter);
      if (typeFilter) params.append('type', typeFilter);

      const response = await api.get(`/activities?${params}`);
      setActivities(response.data.activities);
      setTotalPages(response.data.pagination.totalPages);
    } catch (err) {
      setError('Errore nel caricamento delle attività');
      console.error(err);
    }
  };

  const fetchUsers = async () => {
    try {
      const response = await api.get('/auth/users');
      setUsers(response.data);
    } catch (err) {
      console.error('Errore nel caricamento utenti:', err);
    }
  };

  const handleSubmit = async () => {
    try {
      const submitData = {
        ...formData,
        priority: parseInt(formData.priority),
        assignedToId: parseInt(formData.assignedToId),
        dueDate: new Date(formData.dueDate).toISOString()
      };

      if (editingId) {
        await api.put(`/activities/${editingId}`, submitData);
      } else {
        await api.post('/activities', submitData);
      }
      
      setOpen(false);
      resetForm();
      fetchActivities();
    } catch (err: any) {
      setError(err.response?.data?.message || 'Errore nel salvataggio');
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Sei sicuro di voler eliminare questa attività?')) {
      try {
        await api.delete(`/activities/${id}`);
        fetchActivities();
      } catch (err: any) {
        setError(err.response?.data?.message || 'Errore nell\'eliminazione');
      }
    }
  };

  const handleStatusChange = async (id: number, newStatus: string) => {
    try {
      setError('');
      
      const currentActivity = activities.find(a => a.id === id);
      if (!currentActivity) {
        setError('Attività non trovata');
        return;
      }
      
      const updateData: any = {
        title: currentActivity.title,
        description: currentActivity.description,
        type: currentActivity.type,
        status: newStatus,
        dueDate: currentActivity.dueDate,
        priority: currentActivity.priority,
        assignedToId: currentActivity.assignedToId
      };
      
      if (newStatus === 'completed') {
        updateData.completedDate = new Date().toISOString();
      }
      
      await api.put(`/activities/${id}`, updateData);
      await fetchActivities();
      
    } catch (err: any) {
      console.error('Errore aggiornamento attività:', err);
      const errorMessage = err.response?.data?.message || 
                          err.response?.data?.errors?.[0]?.msg || 
                          'Errore nell\'aggiornamento';
      setError(errorMessage);
    }
  };

  const handleEdit = (activity: Activity) => {
    setEditingId(activity.id);
    setFormData({
      title: activity.title,
      description: activity.description || '',
      type: activity.type,
      status: activity.status,
      dueDate: activity.dueDate.split('T')[0] + 'T' + activity.dueDate.split('T')[1]?.split('.')[0] || '',
      priority: activity.priority.toString(),
      assignedToId: activity.assignedToId.toString()
    });
    setOpen(true);
  };

  const handleView = (activity: Activity) => {
    setViewingActivity(activity);
    setViewOpen(true);
  };

  const resetForm = () => {
    setFormData({
      title: '',
      description: '',
      type: 'task',
      status: 'pending',
      dueDate: '',
      priority: '2',
      assignedToId: ''
    });
    setEditingId(null);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('it-IT');
  };

  const formatDateTime = (dateString: string) => {
    return new Date(dateString).toLocaleString('it-IT');
  };

  const isOverdue = (dueDate: string, status: string) => {
    return status !== 'completed' && new Date(dueDate) < new Date();
  };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" component="h1">
          Attività
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => {
            resetForm();
            setOpen(true);
          }}
        >
          Nuova Attività
        </Button>
      </Box>

      {error && (
        <Alert 
          severity="error" 
          sx={{ mb: 2 }} 
          onClose={() => setError('')}
          action={
            <Button color="inherit" size="small" onClick={() => setError('')}>
              Chiudi
            </Button>
          }
        >
          {error}
        </Alert>
      )}

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2}>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Filtra per Stato</InputLabel>
                <Select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  label="Filtra per Stato"
                >
                  <MenuItem value="">Tutti</MenuItem>
                  {Object.entries(statusLabels).map(([value, label]) => (
                    <MenuItem key={value} value={value}>{label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
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
          </Grid>
        </CardContent>
      </Card>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Titolo</TableCell>
              <TableCell>Tipo</TableCell>
              <TableCell>Assegnata a</TableCell>
              <TableCell>Priorità</TableCell>
              <TableCell>Stato</TableCell>
              <TableCell>Scadenza</TableCell>
              <TableCell>Creata</TableCell>
              <TableCell>Azioni</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {activities.map((activity) => (
              <TableRow 
                key={activity.id}
                sx={{
                  backgroundColor: isOverdue(activity.dueDate, activity.status) ? 'rgba(255, 0, 0, 0.1)' : 'inherit'
                }}
              >
                <TableCell>
                  <Typography variant="subtitle2">{activity.title}</Typography>
                  {activity.description && (
                    <Typography variant="body2" color="text.secondary">
                      {activity.description.substring(0, 50)}...
                    </Typography>
                  )}
                </TableCell>
                <TableCell>
                  <Chip
                    label={typeLabels[activity.type]}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {activity.assignedTo.firstName} {activity.assignedTo.lastName}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {activity.assignedTo.email}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip
                    label={priorityLabels[activity.priority]}
                    color={priorityColors[activity.priority] as any}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    label={statusLabels[activity.status]}
                    color={statusColors[activity.status] as any}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  <Typography 
                    variant="body2"
                    color={isOverdue(activity.dueDate, activity.status) ? 'error' : 'inherit'}
                  >
                    {formatDateTime(activity.dueDate)}
                  </Typography>
                  {activity.completedDate && (
                    <Typography variant="caption" color="text.secondary" display="block">
                      Completata: {formatDateTime(activity.completedDate)}
                    </Typography>
                  )}
                </TableCell>
                <TableCell>{formatDate(activity.createdAt)}</TableCell>
                <TableCell>
                  <IconButton 
                    onClick={() => handleView(activity)} 
                    size="small"
                    title="Visualizza"
                  >
                    <ViewIcon />
                  </IconButton>
                  {activity.status === 'pending' && (
                    <IconButton 
                      onClick={() => handleStatusChange(activity.id, 'in_progress')} 
                      size="small"
                      title="Inizia"
                    >
                      <StartIcon />
                    </IconButton>
                  )}
                  {activity.status === 'in_progress' && (
                    <IconButton 
                      onClick={() => handleStatusChange(activity.id, 'completed')} 
                      size="small"
                      title="Completa"
                    >
                      <CheckIcon />
                    </IconButton>
                  )}
                  <IconButton onClick={() => handleEdit(activity)} size="small">
                    <EditIcon />
                  </IconButton>
                  <IconButton onClick={() => handleDelete(activity.id)} size="small">
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
          {editingId ? 'Modifica Attività' : 'Nuova Attività'}
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
                <InputLabel>Stato</InputLabel>
                <Select
                  value={formData.status}
                  onChange={(e) => setFormData({ ...formData, status: e.target.value })}
                  label="Stato"
                >
                  {Object.entries(statusLabels).map(([value, label]) => (
                    <MenuItem key={value} value={value}>{label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth required>
                <InputLabel>Priorità</InputLabel>
                <Select
                  value={formData.priority}
                  onChange={(e) => setFormData({ ...formData, priority: e.target.value })}
                  label="Priorità"
                >
                  {Object.entries(priorityLabels).map(([value, label]) => (
                    <MenuItem key={value} value={value}>{label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth required>
                <InputLabel>Assegna a</InputLabel>
                <Select
                  value={formData.assignedToId}
                  onChange={(e) => setFormData({ ...formData, assignedToId: e.target.value })}
                  label="Assegna a"
                >
                  {users.map((user) => (
                    <MenuItem key={user.id} value={user.id.toString()}>
                      {user.firstName} {user.lastName} ({user.email})
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Data e Ora di Scadenza"
                type="datetime-local"
                value={formData.dueDate}
                onChange={(e) => setFormData({ ...formData, dueDate: e.target.value })}
                InputLabelProps={{ shrink: true }}
                required
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

      {/* Dialog per visualizzazione dettagli attività */}
      <Dialog open={viewOpen} onClose={() => setViewOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          Dettagli Attività
        </DialogTitle>
        <DialogContent>
          {viewingActivity && (
            <Box sx={{ pt: 2 }}>
              <Typography variant="h6" gutterBottom>
                {viewingActivity.title}
              </Typography>
              
              <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 2, mt: 2 }}>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Tipo</Typography>
                  <Chip
                    label={typeLabels[viewingActivity.type]}
                    size="small"
                    variant="outlined"
                  />
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Stato</Typography>
                  <Chip
                    label={statusLabels[viewingActivity.status]}
                    color={statusColors[viewingActivity.status] as any}
                    size="small"
                  />
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Priorità</Typography>
                  <Chip
                    label={priorityLabels[viewingActivity.priority]}
                    color={priorityColors[viewingActivity.priority] as any}
                    size="small"
                  />
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Assegnata a</Typography>
                  <Typography variant="body1">
                    {viewingActivity.assignedTo.firstName} {viewingActivity.assignedTo.lastName}
                    <Typography variant="caption" color="text.secondary" component="span">
                      {' - '}{viewingActivity.assignedTo.email}
                    </Typography>
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Scadenza</Typography>
                  <Typography 
                    variant="body1"
                    color={isOverdue(viewingActivity.dueDate, viewingActivity.status) ? 'error' : 'inherit'}
                  >
                    {formatDateTime(viewingActivity.dueDate)}
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Data Creazione</Typography>
                  <Typography variant="body1">{formatDate(viewingActivity.createdAt)}</Typography>
                </Box>
              </Box>
              
              {viewingActivity.description && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" color="text.secondary">Descrizione</Typography>
                  <Typography variant="body1" sx={{ whiteSpace: 'pre-wrap' }}>
                    {viewingActivity.description}
                  </Typography>
                </Box>
              )}
              
              {viewingActivity.completedDate && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" color="text.secondary">Data Completamento</Typography>
                  <Typography variant="body1">{formatDateTime(viewingActivity.completedDate)}</Typography>
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
              handleEdit(viewingActivity!);
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

export default Activities;