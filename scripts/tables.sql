-- Create users table
CREATE TABLE IF NOT EXISTS user_daily_usage(
    user_id UUID REFERENCES auth.users (id),
    email TEXT,
    date TEXT,
    daily_requests_count INT,
    PRIMARY KEY (user_id, date)
);

-- Create chats table
CREATE TABLE IF NOT EXISTS chats(
    chat_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users (id),
    creation_time TIMESTAMP DEFAULT current_timestamp,
    history JSONB,
    chat_name TEXT
);


-- Create vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create vectors table
CREATE TABLE IF NOT EXISTS vectors (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    content TEXT,
    file_sha1 TEXT,
    metadata JSONB,
    embedding VECTOR(1536)
);

-- Create function to match vectors
CREATE OR REPLACE FUNCTION match_vectors(query_embedding VECTOR(1536), match_count INT, p_brain_id UUID)
RETURNS TABLE(
    id UUID,
    brain_id UUID,
    content TEXT,
    metadata JSONB,
    embedding VECTOR(1536),
    similarity FLOAT
) LANGUAGE plpgsql AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY
    SELECT
        vectors.id,
        brains_vectors.brain_id,
        vectors.content,
        vectors.metadata,
        vectors.embedding,
        1 - (vectors.embedding <=> query_embedding) AS similarity
    FROM
        vectors
    INNER JOIN
        brains_vectors ON vectors.id = brains_vectors.vector_id
    WHERE brains_vectors.brain_id = p_brain_id
    ORDER BY
        vectors.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Create stats table
CREATE TABLE IF NOT EXISTS stats (
    time TIMESTAMP,
    chat BOOLEAN,
    embedding BOOLEAN,
    details TEXT,
    metadata JSONB,
    id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY
);

-- Create summaries table
CREATE TABLE IF NOT EXISTS summaries (
    id BIGSERIAL PRIMARY KEY,
    document_id UUID REFERENCES vectors(id),
    content TEXT,
    metadata JSONB,
    embedding VECTOR(1536)
);

-- Create function to match summaries
CREATE OR REPLACE FUNCTION match_summaries(query_embedding VECTOR(1536), match_count INT, match_threshold FLOAT)
RETURNS TABLE(
    id BIGINT,
    document_id UUID,
    content TEXT,
    metadata JSONB,
    embedding VECTOR(1536),
    similarity FLOAT
) LANGUAGE plpgsql AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY
    SELECT
        id,
        document_id,
        content,
        metadata,
        embedding,
        1 - (summaries.embedding <=> query_embedding) AS similarity
    FROM
        summaries
    WHERE 1 - (summaries.embedding <=> query_embedding) > match_threshold
    ORDER BY
        summaries.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Create api_keys table
CREATE TABLE IF NOT EXISTS api_keys(
    key_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users (id),
    api_key TEXT UNIQUE,
    creation_time TIMESTAMP DEFAULT current_timestamp,
    deleted_time TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

--- Create prompts table
CREATE TABLE IF NOT EXISTS prompts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title VARCHAR(255),
    content TEXT,
    status VARCHAR(255) DEFAULT 'private'
);

--- Create brains table
CREATE TABLE IF NOT EXISTS brains (
  brain_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  status TEXT,
  description TEXT,
  model TEXT,
  max_tokens INT,
  temperature FLOAT,
  openai_api_key TEXT,
  prompt_id UUID REFERENCES prompts(id),
  last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Create chat_history table
CREATE TABLE IF NOT EXISTS chat_history (
    message_id UUID DEFAULT uuid_generate_v4(),
    chat_id UUID REFERENCES chats(chat_id),
    user_message TEXT,
    assistant TEXT,
    message_time TIMESTAMP DEFAULT current_timestamp,
    PRIMARY KEY (chat_id, message_id),
    prompt_id UUID REFERENCES prompts(id),
    brain_id UUID REFERENCES brains(brain_id)
);

-- Create notification table

CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  chat_id UUID REFERENCES chats(chat_id),
  message TEXT,
  action VARCHAR(255) NOT NULL,
  status VARCHAR(255) NOT NULL
);


-- Create brains X users table
CREATE TABLE IF NOT EXISTS brains_users (
  brain_id UUID,
  user_id UUID,
  rights VARCHAR(255),
  default_brain BOOLEAN DEFAULT false,
  PRIMARY KEY (brain_id, user_id),
  FOREIGN KEY (user_id) REFERENCES auth.users (id),
  FOREIGN KEY (brain_id) REFERENCES brains (brain_id)
);

-- Create brains X vectors table
CREATE TABLE IF NOT EXISTS brains_vectors (
  brain_id UUID,
  vector_id UUID,
  file_sha1 TEXT,
  PRIMARY KEY (brain_id, vector_id),
  FOREIGN KEY (vector_id) REFERENCES vectors (id),
  FOREIGN KEY (brain_id) REFERENCES brains (brain_id)
);

-- Create brains X vectors table
CREATE TABLE IF NOT EXISTS brain_subscription_invitations (
  brain_id UUID,
  email VARCHAR(255),
  rights VARCHAR(255),
  PRIMARY KEY (brain_id, email),
  FOREIGN KEY (brain_id) REFERENCES brains (brain_id)
);

--- Create user_identity table
CREATE TABLE IF NOT EXISTS user_identity (
  user_id UUID PRIMARY KEY,
  openai_api_key VARCHAR(255)
);


CREATE OR REPLACE FUNCTION public.get_user_email_by_user_id(user_id uuid)
RETURNS TABLE (email text)
SECURITY definer
AS $$
BEGIN
  RETURN QUERY SELECT au.email::text FROM auth.users au WHERE au.id = user_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.get_user_id_by_user_email(user_email text)
RETURNS TABLE (user_id uuid)
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY SELECT au.id::uuid FROM auth.users au WHERE au.email = user_email;
END;
$$ LANGUAGE plpgsql;



CREATE TABLE IF NOT EXISTS migrations (
  name VARCHAR(255)  PRIMARY KEY,
  executed_at TIMESTAMPTZ DEFAULT current_timestamp
);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY,
  models JSONB DEFAULT '["gpt-3.5-turbo"]'::jsonb,
  max_requests_number INT DEFAULT 50,
  max_brains INT DEFAULT 5,
  max_brain_size INT DEFAULT 10000000
);

-- knowledge table
CREATE TABLE IF NOT EXISTS knowledge (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  file_name TEXT,
  url TEXT,
  brain_id UUID NOT NULL REFERENCES brains(brain_id),
  extension TEXT NOT NULL,
  CHECK ((file_name IS NOT NULL AND url IS NULL) OR (file_name IS NULL AND url IS NOT NULL))
);


-- knowledge_vectors table
CREATE TABLE IF NOT EXISTS knowledge_vectors (
  knowledge_id UUID NOT NULL REFERENCES knowledge(id),
  vector_id UUID NOT NULL REFERENCES vectors(id),
  embedding_model TEXT NOT NULL,
  PRIMARY KEY (knowledge_id, vector_id, embedding_model)
);


insert into
  storage.buckets (id, name)
values
  ('quivr', 'quivr');

CREATE POLICY "Access Quivr Storage 1jccrwz_0" ON storage.objects FOR INSERT TO anon WITH CHECK (bucket_id = 'quivr');

CREATE POLICY "Access Quivr Storage 1jccrwz_1" ON storage.objects FOR SELECT TO anon USING (bucket_id = 'quivr');

CREATE POLICY "Access Quivr Storage 1jccrwz_2" ON storage.objects FOR UPDATE TO anon USING (bucket_id = 'quivr');

CREATE POLICY "Access Quivr Storage 1jccrwz_3" ON storage.objects FOR DELETE TO anon USING (bucket_id = 'quivr');

INSERT INTO migrations (name) 
SELECT '20230921160000_add_last_update_field_to_brain'
WHERE NOT EXISTS (
    SELECT 1 FROM migrations WHERE name = '20230921160000_add_last_update_field_to_brain'
);


