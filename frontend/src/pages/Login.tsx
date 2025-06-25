import React, { useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Alert,
  CircularProgress,
  Container,
} from '@mui/material';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

const schema = yup.object({
  email: yup.string().email('Email non valida').required('Email richiesta'),
  password: yup.string().required('Password richiesta'),
});

interface LoginForm {
  email: string;
  password: string;
}

const Login: React.FC = () => {
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginForm>({
    resolver: yupResolver(schema),
  });

  const onSubmit = async (data: LoginForm) => {
    setError('');
    setIsLoading(true);

    try {
      await login(data.email, data.password);
      navigate('/');
    } catch (err: any) {
      setError(err.response?.data?.message || 'Errore durante il login');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Container component="main" maxWidth="sm">
      <Box
        sx={{
          marginTop: 8,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <Card sx={{ width: '100%', maxWidth: 400 }}>
          <CardContent sx={{ p: 4 }}>
            <Typography component="h1" variant="h4" align="center" gutterBottom>
              CRM System
            </Typography>
            <Typography variant="body2" align="center" color="text.secondary" mb={3}>
              Accedi al tuo account
            </Typography>

            {error && (
              <Alert severity="error" sx={{ mb: 2 }}>
                {error}
              </Alert>
            )}

            <Box component="form" onSubmit={handleSubmit(onSubmit)} noValidate>
              <TextField
                margin="normal"
                required
                fullWidth
                id="email"
                label="Email"
                type="email"
                autoComplete="email"
                autoFocus
                {...register('email')}
                error={!!errors.email}
                helperText={errors.email?.message}
              />
              <TextField
                margin="normal"
                required
                fullWidth
                label="Password"
                type="password"
                id="password"
                autoComplete="current-password"
                {...register('password')}
                error={!!errors.password}
                helperText={errors.password?.message}
              />
              <Button
                type="submit"
                fullWidth
                variant="contained"
                sx={{ mt: 3, mb: 2 }}
                disabled={isLoading}
                startIcon={isLoading && <CircularProgress size={20} />}
              >
                {isLoading ? 'Accesso in corso...' : 'Accedi'}
              </Button>
            </Box>

            <Box mt={2} p={2} bgcolor="grey.100" borderRadius={1}>
              <Typography variant="body2" align="center" gutterBottom>
                <strong>Account di prova:</strong>
              </Typography>
              <Typography variant="body2" align="center">
                Email: admin@crm.local
              </Typography>
              <Typography variant="body2" align="center">
                Password: admin123
              </Typography>
            </Box>
          </CardContent>
        </Card>
      </Box>
    </Container>
  );
};

export default Login;