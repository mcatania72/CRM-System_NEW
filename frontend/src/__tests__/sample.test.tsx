// frontend/src/__tests__/sample.test.tsx

import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';

// Un semplice componente React di esempio da testare
const SampleComponent: React.FC = () => {
  return (
    <div>
      <h1>Hello, World!</h1>
      <p>This is a sample test.</p>
    </div>
  );
};

describe('Sample Frontend Test Suite', () => {
  it('should render the sample component correctly', () => {
    // Renderizza il componente
    render(<SampleComponent />);

    // Cerca l'intestazione e verifica il suo contenuto
    const headingElement = screen.getByText(/Hello, World!/i);
    expect(headingElement).toBeDefined();
  });

  it('should always pass this simple test', () => {
    expect(1).toBe(1);
  });
});
