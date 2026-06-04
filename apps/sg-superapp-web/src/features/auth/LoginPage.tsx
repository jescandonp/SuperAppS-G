import { useState } from "react";

interface LoginPageProps {
  loading: boolean;
  errorMessage: string | null;
  onSubmit: (username: string, password: string) => Promise<void>;
}

export function LoginPage({ loading, errorMessage, onSubmit }: LoginPageProps) {
  const [username, setUsername] = useState("admin.sg");
  const [password, setPassword] = useState("Admin123");

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await onSubmit(username, password);
  }

  return (
    <main className="login-page">
      <section className="login-card">
        <div>
          <p className="eyebrow">S&amp;G Super App</p>
          <h1>Portal interno</h1>
          <p className="muted">Acceso administrativo del piloto de Talento Humano.</p>
        </div>

        <form className="login-form" onSubmit={handleSubmit}>
          <label>
            Usuario
            <input type="text" placeholder="admin.sg" value={username} onChange={(event) => setUsername(event.target.value)} />
          </label>
          <label>
            Contrasena
            <input type="password" placeholder="********" value={password} onChange={(event) => setPassword(event.target.value)} />
          </label>
          {errorMessage ? <p className="error-text">{errorMessage}</p> : null}
          <button type="submit" disabled={loading}>{loading ? "Validando..." : "Ingresar"}</button>
        </form>
      </section>
    </main>
  );
}
