# Vendas 360

App PWA para representantes comerciais de campo. Monta rota inteligente por ciclo de compras + distância GPS, com agendamento de clientes chave e análise de vendas.

## Acesso

**App (produção):**
https://projetosgestaopec360-cmd.github.io/vendas360/vendas360_v6.html

**Banco de dados:**
Supabase — solicitar acesso ao owner do projeto.

## Stack

- **Frontend:** HTML + CSS + JavaScript puro (single file PWA)
- **Backend:** Supabase (PostgreSQL + Auth + RLS)
- **Hospedagem:** GitHub Pages

## Estrutura do banco

| Tabela | Descrição |
|--------|-----------|
| `vendedores` | Perfil de cada representante (ligado ao Supabase Auth) |
| `clientes` | Carteira de clientes de cada vendedor |
| `visitas` | Registro diário de visitas e vendas |
| `agendamentos` | Agendamento mensal de clientes chave |
| `rotas_semanais` | Planejamento semanal (JSONB) |
| `dias_trabalho` | Resumo diário de performance |
| `alertas` | Alertas automáticos |

## Lógica de negócio

**Ciclo de visitas:**
- Cliente entra na rota quando: `dias_desde_compra >= ciclo_dias - 10`
- **Cliente chave:** entra na rota todo ciclo independente de compra

**Algoritmo de rota:**
- Com GPS: Nearest Neighbor a partir da posição do vendedor
- Sem GPS: ordena por urgência do ciclo (`dias / ciclo_dias` desc)
- Clientes chave são priorizados e distribuídos primeiro

**GPS automático:**
- Ao registrar uma visita, o app captura a localização do vendedor
- Trigger no banco atualiza automaticamente as coordenadas do cliente
- A rota fica progressivamente mais precisa a cada visita

## Como configurar um novo ambiente

1. Crie um projeto no Supabase
2. Execute o arquivo `schema.sql` no SQL Editor
3. Ative o Email Provider em Authentication > Providers
4. Desmarque "Confirm email" para testes
5. Atualize `SUPA_URL` e `SUPA_KEY` no `vendas360_v6.html`
6. Faça o deploy no GitHub Pages ou Netlify

## Conexão Python (para desenvolvimento)

```python
from supabase import create_client

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# Buscar todos os clientes
clientes = supabase.table("clientes").select("*").execute()

# Buscar visitas de um vendedor
visitas = supabase.table("visitas")\
    .select("*, clientes(nome, cidade)")\
    .eq("vendedor_id", VENDEDOR_ID)\
    .execute()
```

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `vendas360_v6.html` | App completo (frontend) |
| `schema.sql` | Estrutura completa do banco |
| `manifest.json` | Configuração PWA |
| `sw.js` | Service Worker (cache offline) |
| `icon-192.png` / `icon-512.png` | Ícones do app |
| `index.html` | Redirecionamento para o app |
