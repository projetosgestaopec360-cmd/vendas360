-- ============================================================
-- VENDAS 360 — Schema completo do banco de dados
-- Supabase / PostgreSQL
-- ============================================================
-- Para recriar o banco em um novo projeto Supabase:
-- 1. Acesse o SQL Editor no painel do Supabase
-- 2. Cole este arquivo e execute
-- ============================================================

-- Extensões necessárias
create extension if not exists "uuid-ossp";
create extension if not exists pg_trgm;

-- ============================================================
-- TABELA: vendedores
-- Perfil de cada representante comercial
-- Ligado ao auth.users do Supabase Auth
-- ============================================================
create table public.vendedores (
  id            uuid primary key default gen_random_uuid(),
  auth_id       uuid unique references auth.users(id) on delete cascade,
  nome          text not null,
  email         text unique,
  empresa       text,
  telefone      text,
  plano         text default 'trial',
  ativo         boolean default true,
  meta_diaria   numeric default 0,
  meta_mensal   numeric default 0,
  vendido_mes   numeric default 0,
  max_rota      integer default 15,
  tipo_rota     text default 'diaria' check (tipo_rota in ('diaria','semanal')),
  criado_em     timestamptz default now(),
  atualizado_em timestamptz default now()
);

-- ============================================================
-- TABELA: clientes
-- Carteira de clientes de cada vendedor
-- ============================================================
create table public.clientes (
  id                   uuid primary key default gen_random_uuid(),
  vendedor_id          uuid references public.vendedores(id) on delete cascade,
  nome                 text not null,
  cidade               text,
  estado               text default 'CE',
  endereco             text,
  telefone             text,
  aniversario          date,
  ultima_compra        date,
  valor_medio_compra   numeric default 0,  -- campo legado
  valor_medio          numeric default 0,  -- campo atual
  frequencia_media_dias integer default 30, -- campo legado
  ciclo_dias           integer default 30,  -- campo atual
  canal                text,               -- CONSUMIDOR ou REVENDA
  cliente_chave        boolean default false, -- visita obrigatoria todo ciclo
  score_prioridade     integer default 0 check (score_prioridade >= 0 and score_prioridade <= 100),
  status               text default 'ativo' check (status in ('urgente','atencao','ativo','inativo')),
  lat                  numeric(10,7),       -- GPS do cliente (atualizado automaticamente nas visitas)
  lng                  numeric(10,7),
  observacoes          text,
  ativo                boolean default true,
  criado_em            timestamptz default now(),
  atualizado_em        timestamptz default now()
);

-- ============================================================
-- TABELA: visitas
-- Registro de cada visita feita pelo vendedor
-- ============================================================
create table public.visitas (
  id               uuid primary key default gen_random_uuid(),
  cliente_id       uuid references public.clientes(id) on delete cascade,
  vendedor_id      uuid references public.vendedores(id) on delete cascade,
  visitou          boolean default false,
  vendeu           boolean default false,
  valor_vendido    numeric default 0,
  motivo_nao_venda text,
  observacoes      text,
  data_visita      date default current_date,
  lat_visita       numeric(10,7),  -- GPS capturado no momento da visita
  lng_visita       numeric(10,7),  -- atualiza automaticamente o GPS do cliente
  registrado_em    timestamptz default now()
);

-- ============================================================
-- TABELA: agendamentos
-- Agendamento mensal de visitas aos clientes chave
-- ============================================================
create table public.agendamentos (
  id            uuid primary key default gen_random_uuid(),
  vendedor_id   uuid not null references public.vendedores(id) on delete cascade,
  cliente_id    uuid not null references public.clientes(id) on delete cascade,
  mes           integer not null,
  ano           integer not null,
  dia_agendado  date,
  periodo       text check (periodo in ('manha','tarde','dia_todo')),
  confirmado    boolean default false,
  mensagem_env  boolean default false, -- se ja enviou whatsapp
  observacoes   text,
  criado_em     timestamptz default now(),
  atualizado_em timestamptz default now(),
  unique(vendedor_id, cliente_id, mes, ano)
);

-- ============================================================
-- TABELA: rotas_semanais
-- Planejamento semanal salvo (JSONB com dias e IDs de clientes)
-- ============================================================
create table public.rotas_semanais (
  id          uuid primary key default gen_random_uuid(),
  vendedor_id uuid not null references public.vendedores(id) on delete cascade,
  semana      text not null,   -- ex: "18-2026"
  gerado_em   timestamptz default now(),
  dias        jsonb not null,  -- [{dia:"Segunda", ids:[...]}, ...]
  unique(vendedor_id, semana)
);

-- ============================================================
-- TABELA: dias_trabalho
-- Resumo diário de performance + feedback IA
-- ============================================================
create table public.dias_trabalho (
  id                 uuid primary key default gen_random_uuid(),
  vendedor_id        uuid references public.vendedores(id) on delete cascade,
  data               date default current_date,
  meta_dia           numeric default 0,
  vendido_dia        numeric default 0,
  clientes_visitados integer default 0,
  clientes_vendidos  integer default 0,
  feedback_ia        text,
  unique(vendedor_id, data)
);

-- ============================================================
-- TABELA: alertas
-- Alertas automáticos para o vendedor
-- ============================================================
create table public.alertas (
  id          uuid primary key default gen_random_uuid(),
  vendedor_id uuid references public.vendedores(id) on delete cascade,
  cliente_id  uuid references public.clientes(id) on delete cascade,
  tipo        text not null check (tipo in ('ciclo_vencido','inativo','aniversario','boleto','pos_venda','churn')),
  mensagem    text,
  lido        boolean default false,
  criado_em   timestamptz default now()
);

-- ============================================================
-- TABELA: logs_acesso
-- Log de acessos dos vendedores
-- ============================================================
create table public.logs_acesso (
  id          uuid primary key default gen_random_uuid(),
  vendedor_id uuid references public.vendedores(id) on delete cascade,
  acao        text not null,
  ip          text,
  dispositivo text,
  criado_em   timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- Cada vendedor acessa apenas seus próprios dados
-- ============================================================

alter table public.vendedores     enable row level security;
alter table public.clientes       enable row level security;
alter table public.visitas        enable row level security;
alter table public.agendamentos   enable row level security;
alter table public.rotas_semanais enable row level security;
alter table public.dias_trabalho  enable row level security;
alter table public.alertas        enable row level security;
alter table public.logs_acesso    enable row level security;

-- Vendedores
create policy "vendedor_proprio" on public.vendedores
  for all using (auth.uid() = auth_id) with check (auth.uid() = auth_id);

-- Clientes
create policy "clientes_proprio_vendedor" on public.clientes
  for all using (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  ) with check (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  );

-- Visitas
create policy "visitas_proprio_vendedor" on public.visitas
  for all using (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  ) with check (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  );

-- Agendamentos
create policy "agendamentos_proprio_vendedor" on public.agendamentos
  for all using (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  ) with check (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  );

-- Rotas semanais
create policy "rota_proprio_vendedor" on public.rotas_semanais
  for all using (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  ) with check (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  );

-- Dias trabalho
create policy "dias_proprio_vendedor" on public.dias_trabalho
  for all using (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  ) with check (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  );

-- Alertas
create policy "alertas_proprio_vendedor" on public.alertas
  for all using (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  );

-- Logs
create policy "logs_proprio_vendedor" on public.logs_acesso
  for all using (
    vendedor_id = (select id from public.vendedores where auth_id = auth.uid() limit 1)
  );

-- ============================================================
-- TRIGGER: criar perfil automaticamente no cadastro
-- Quando um novo usuário se cadastra no Supabase Auth,
-- cria automaticamente o perfil na tabela vendedores
-- ============================================================
create or replace function public.criar_perfil_vendedor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.vendedores (auth_id, nome, email, empresa)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'empresa', '')
  )
  on conflict (auth_id) do update
    set nome  = coalesce(excluded.nome, vendedores.nome),
        email = excluded.email;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.criar_perfil_vendedor();

-- ============================================================
-- TRIGGER: atualizar GPS do cliente ao registrar visita
-- Quando uma visita é registrada com GPS,
-- atualiza automaticamente as coordenadas do cliente
-- ============================================================
create or replace function public.atualizar_gps_cliente()
returns trigger language plpgsql security definer as $$
begin
  if new.lat_visita is not null and new.lng_visita is not null then
    update public.clientes
    set lat = new.lat_visita,
        lng = new.lng_visita,
        atualizado_em = now()
    where id = new.cliente_id;
  end if;
  return new;
end;
$$;

create trigger on_visita_com_gps
  after insert or update on public.visitas
  for each row execute procedure public.atualizar_gps_cliente();

-- ============================================================
-- FUNÇÕES UTILITÁRIAS
-- ============================================================

-- Importar clientes em lote (usado pelo app na importação de planilha)
create or replace function public.importar_clientes(
  p_vendedor_id uuid,
  p_clientes    jsonb
)
returns jsonb language plpgsql security definer as $$
declare
  v_cliente jsonb;
  v_count   integer := 0;
  v_erros   integer := 0;
  v_nome    text;
  v_ult     date;
  v_aniv    date;
begin
  for v_cliente in select * from jsonb_array_elements(p_clientes) loop
    begin
      v_nome := trim(v_cliente->>'nome');
      if v_nome is null or v_nome = '' then continue; end if;
      begin v_ult := (v_cliente->>'ultima_compra')::date;
      exception when others then v_ult := null; end;
      begin v_aniv := (v_cliente->>'aniversario')::date;
      exception when others then v_aniv := null; end;
      insert into public.clientes (
        vendedor_id, nome, cidade, telefone, endereco,
        ultima_compra, valor_medio, ciclo_dias,
        aniversario, canal, observacoes, cliente_chave, ativo
      ) values (
        p_vendedor_id, v_nome,
        nullif(trim(v_cliente->>'cidade'), ''),
        nullif(trim(v_cliente->>'telefone'), ''),
        nullif(trim(v_cliente->>'endereco'), ''),
        v_ult,
        coalesce((v_cliente->>'valor_medio')::numeric, 0),
        coalesce((v_cliente->>'ciclo_dias')::integer, 30),
        v_aniv,
        nullif(trim(upper(v_cliente->>'canal')), ''),
        nullif(trim(v_cliente->>'observacoes'), ''),
        coalesce((v_cliente->>'cliente_chave')::boolean, false),
        true
      ) on conflict do nothing;
      v_count := v_count + 1;
    exception when others then
      v_erros := v_erros + 1;
    end;
  end loop;
  return jsonb_build_object('importados', v_count, 'erros', v_erros);
end;
$$;

grant execute on function public.importar_clientes(uuid, jsonb) to authenticated;

-- Buscar clientes por nome ou cidade
create or replace function public.buscar_clientes(
  p_vendedor_id uuid,
  p_termo       text,
  p_limite      integer default 20
)
returns table (
  id uuid, nome text, cidade text, telefone text,
  ultima_compra date, valor_medio numeric, ciclo_dias integer,
  lat numeric, lng numeric, canal text, observacoes text,
  aniversario date, ativo boolean, cliente_chave boolean
)
language sql security definer as $$
  select id, nome, cidade, telefone, ultima_compra,
    coalesce(valor_medio, valor_medio_compra, 0),
    coalesce(ciclo_dias, frequencia_media_dias, 30),
    lat, lng, canal, observacoes, aniversario, ativo, cliente_chave
  from public.clientes
  where vendedor_id = p_vendedor_id and ativo = true
    and (nome ilike '%' || p_termo || '%' or cidade ilike '%' || p_termo || '%')
  order by case when nome ilike p_termo || '%' then 0 else 1 end, nome
  limit p_limite;
$$;

grant execute on function public.buscar_clientes(uuid, text, integer) to authenticated;

-- Carregar carteira completa paginada
create or replace function public.carregar_clientes(
  p_vendedor_id uuid,
  p_limite      integer default 500,
  p_offset      integer default 0
)
returns table (
  id uuid, nome text, cidade text, telefone text, endereco text,
  ultima_compra date, valor_medio numeric, ciclo_dias integer,
  aniversario date, canal text, observacoes text,
  lat numeric, lng numeric, ativo boolean,
  cliente_chave boolean, atualizado_em timestamptz
)
language sql security definer as $$
  select id, nome, cidade, telefone, endereco, ultima_compra,
    coalesce(valor_medio, valor_medio_compra, 0),
    coalesce(ciclo_dias, frequencia_media_dias, 30),
    aniversario, canal, observacoes, lat, lng, ativo,
    coalesce(cliente_chave, false), atualizado_em
  from public.clientes
  where vendedor_id = p_vendedor_id and ativo = true
  order by nome
  limit p_limite offset p_offset;
$$;

grant execute on function public.carregar_clientes(uuid, integer, integer) to authenticated;

-- Registrar venda e atualizar valor médio do cliente (média ponderada 70/30)
create or replace function public.registrar_venda(
  p_cliente_id  uuid,
  p_vendedor_id uuid,
  p_valor       numeric,
  p_data        date default current_date
)
returns void language plpgsql security definer as $$
begin
  update public.clientes
  set ultima_compra = p_data,
      valor_medio = case
        when valor_medio > 0 then round((valor_medio * 0.7 + p_valor * 0.3)::numeric, 2)
        else p_valor
      end,
      atualizado_em = now()
  where id = p_cliente_id and vendedor_id = p_vendedor_id;
end;
$$;

grant execute on function public.registrar_venda(uuid, uuid, numeric, date) to authenticated;

-- ============================================================
-- INDEXES para performance
-- ============================================================
create index if not exists idx_clientes_vendedor      on public.clientes(vendedor_id, ativo);
create index if not exists idx_clientes_chave         on public.clientes(vendedor_id, cliente_chave) where cliente_chave = true;
create index if not exists idx_clientes_nome_trgm     on public.clientes using gin (nome gin_trgm_ops);
create index if not exists idx_clientes_cidade_trgm   on public.clientes using gin (cidade gin_trgm_ops);
create index if not exists idx_visitas_vendedor        on public.visitas(vendedor_id);
create index if not exists idx_visitas_data            on public.visitas(vendedor_id, data_visita);
create index if not exists idx_agendamentos_mes        on public.agendamentos(vendedor_id, mes, ano);
create index if not exists idx_rotas_semana            on public.rotas_semanais(vendedor_id, semana);

-- ============================================================
-- FIM DO SCHEMA
-- ============================================================
