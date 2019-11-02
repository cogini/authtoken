defmodule AuthToken do
  @moduledoc """
  Simplified encrypted authentication tokens using JWE.

  Configuration needed:

    config :authtoken,
      token_key: PUT_KEY_HERE

  Generate a token for your user after successful authentication like this:

  ## Examples

      token_content = %{userid: user.id}

      token = AuthToken.generate_token(token_content)
  """

  @doc """
  Generate random key for AES128.

  ## Examples

      iex> AuthToken.generate_key()
      {:ok, <<153, 67, 252, 211, 199, 186, 212, 114, 109, 99, 222, 205, 31, 26, 100, 253>>}
  """
  @spec generate_key() :: {:ok, binary}
  def generate_key do
    {:ok, :crypto.strong_rand_bytes(16)}
  end

  @doc """
  Generate encrypted auth token.

  The token includes the keys from the provided map, plus timeout (`ct`) and
  refresh (`rt`).

  Reads encryption key from config `token_key`, defaulting to application environment.
  """
  @spec generate_token(map, map) :: {:ok, String.t}
  def generate_token(user_data, config \\ %{}) do
    base_data = %{
      "ct" => DateTime.to_unix(DateTime.utc_now()),
      "rt" => DateTime.to_unix(DateTime.utc_now())}

    token_content = user_data |> Enum.into(base_data)

    jwt = JOSE.JWT.encrypt(get_jwk(config), get_jwe(), token_content) |> JOSE.JWE.compact |> elem(1)

    # Remove JWT header
    {:ok, Regex.run(~r/.+?\.(.+)/, jwt) |> List.last}
  end

  @doc """
  Refresh token if necessary.

  Returns `{:error, :timedout}` if the token has expired.
  Make the user log in again.

  Returns `{:error, :stillfresh}` if the token refresh time has not yet been
  reached. Do nothing.

  Returns `{:ok, token}` with a new token if the token needed to be refreshed.
  The new token has an updated refresh time (`rt`), but keeps the same creation
  time/expiration. Check that the user is still valid and send them the new token.

  ## Examples

      case AuthToken.refresh_token(token) do
        {:error, :timedout} ->
          # Redirect to login
        {:error, :stillfresh} ->
          # Do nothing
        {:ok, token} ->
          # Check credentials and send back new token
      end
  """
  @spec refresh_token(binary | map, map) :: {:ok, String.t} | {:error, :stillfresh} | {:error, :timedout}
  def refresh_token(token, config \\ %{})
  def refresh_token(token, config) when is_map(token) do
    cond do
      is_timedout?(token, config) ->    {:error, :timedout}
      !needs_refresh?(token, config) -> {:error, :stillfresh}

      needs_refresh?(token, config) ->
        token = %{"rt" => DateTime.to_unix(DateTime.utc_now())} |> Enum.into(token)

        generate_token(token, config)
    end
  end
  def refresh_token(bin, config) when is_binary(bin) do
    {:ok, token} = decrypt_token(bin, config)
    refresh_token(token, config)
  end

  @doc """
  Check if token has timed out.

  Reads `timeout` from config, defaulting to application environment.

  If the time since the token creation time (`ct`) exceeds timeout, returns
  true.
  """
  @spec is_timedout?(map, map) :: boolean
  def is_timedout?(token, config \\ %{})
  def is_timedout?(token, config) when is_map(token) do
    {:ok, ct} = DateTime.from_unix(token["ct"])

    duration = config[:timeout] || get_config(:timeout)
    DateTime.diff(DateTime.utc_now(), ct) > duration
  end

  @doc """
  Check if token is stale and needs to be refreshed.

  Reads `refresh` from config, defaulting to application environment.

  If the time since the token refresh time (`rt`) exceeds refresh, returns
  true.

  """
  @spec needs_refresh?(map, map) :: boolean
  def needs_refresh?(token, config \\ %{}) do
    {:ok, rt} = DateTime.from_unix(token["rt"])

    duration = config[:refresh] || get_config(:refresh)
    DateTime.diff(DateTime.utc_now(), rt) > duration
  end

  @doc """
  Decrypt authentication token and return content.

  Accepts a token as input, or you can pass it a `t:Plug.Conn.t/0` and it will
  pull the token from the `authorization` header. It will remove a `bearer`
  prefix, e.g. `bearer: thetoken` or `bearer thetoken`.

  Reads encryption key from config `token_key`, defaulting to application environment.
  """
  @spec decrypt_token(Plug.Conn.t | String.t, map) :: {:ok, map} | {:error}
  def decrypt_token(conn_or_token, config \\ %{})
  def decrypt_token(%Plug.Conn{} = conn, config) do
    token_header = Plug.Conn.get_req_header(conn, "authorization") |> List.first

    crypto_token = if token_header, do: Regex.run(~r/(bearer\:? )?(.+)/, token_header) |> List.last

    decrypt_token(crypto_token, config)
  end

  def decrypt_token(headless_token, config) when is_binary(headless_token) do
    header = get_jwe() |> OJSON.encode! |> :base64url.encode

    auth_token = header <> "." <> headless_token

    try do
      %{fields: token} = JOSE.JWT.decrypt(get_jwk(config), auth_token) |> elem(1)

      {:ok, token}
    rescue
      _ -> {:error}
    end
  end

  def decrypt_token(_, _) do
    {:error}
  end

  # Get jwe params
  @spec get_jwe() :: map
  defp get_jwe do
    %{"alg" => "dir", "enc" => "A128GCM", "typ" => "JWT"}
  end

  # Get JWK params from config or environment
  @spec get_jwk(map) :: %JOSE.JWK{}
  defp get_jwk(config) do
    key = config[:token_key] || get_config(:token_key)
    JOSE.JWK.from_oct(key)
  end

  # Get map
  @spec get_config(atom) :: map
  def get_config(key) do
    content = Application.get_env(:authtoken, key)
    content || raise "Missing AuthToken config for #{key}"
    content
  end
end
