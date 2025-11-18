const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);
const supabaseAdmin = supabaseServiceRoleKey ? createClient(supabaseUrl, supabaseServiceRoleKey) : null;

function escapeHtml(text) {
  return text
    .replace(/&/g, '&')
    .replace(/</g, '<')
    .replace(/>/g, '>')
    .replace(/"/g, '"')
    .replace(/'/g, ''');
}

export default async function handler(req, res) {
  const { username } = req.query;

  if (!username) {
    return res.status(400).json({ error: 'Username required' });
  }

  try {
    if (!supabaseAdmin) {
      return res.status(500).json({ error: 'Server configuration error' });
    }

    // Assume username is email for simplicity
    const { data: user, error: userError } = await supabaseAdmin.auth.admin.getUserByEmail(username);

    if (userError || !user.user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if profile is public
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('public_profile')
      .eq('id', user.user.id)
      .single();

    if (profileError || !profile || !profile.public_profile) {
      return res.status(404).json({ error: 'Profile not found or not public' });
    }

    const { data: history, error: historyError } = await supabase
      .from('distro_history')
      .select('*')
      .eq('user_id', user.user.id)
      .order('start_date', { ascending: true });

    if (historyError) {
      return res.status(500).json({ error: 'Internal server error' });
    }

    // Check if request accepts HTML
    if (req.headers.accept && req.headers.accept.includes('text/html')) {
      const escapedUsername = escapeHtml(username);
      const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Distro History for ${escapedUsername}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    ul { list-style-type: none; padding: 0; }
    li { background: #f4f4f4; margin: 5px 0; padding: 10px; border-radius: 5px; }
    .current { background: #e8f5e8; }
  </style>
</head>
<body>
  <h1>Ubuntu Distribution History for ${escapedUsername}</h1>
  <ul>
    ${history.map(h => `<li class="${h.current_flag ? 'current' : ''}">${escapeHtml(h.distro_name)}: ${h.start_date} - ${h.end_date || 'Current'}</li>`).join('')}
  </ul>
</body>
</html>
      `;
      res.setHeader('Content-Type', 'text/html');
      return res.status(200).send(html);
    } else {
      return res.status(200).json(history);
    }
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}