# AuthToken

[![Travis CI Build Status](https://travis-ci.org/Brainsware/authtoken.svg?branch=master)](https://travis-ci.org/Brainsware/authtoken)

Simplified JWT encrypted authentication tokens.

This package provides you with straightforward encrypted JWE encrypted JWT
tokens. It uses sane sane defaults 128-bit AES encryption (AES128) and minimal
configuration to counteract JWTs overblown complexity.

It strips the header which describes the algorithm from the token, making
it smaller.

Using encrypted tokens allows you to store sensitive data in the token,
unlike hashed tokens which allow anyone to read them. Only apps
with the shared key will be able to decrypt and verify the token.

See this [blog post](https://sealas.at/blog/2017-12/tokens-cookies-and-sessions-an-auth-story-part-1/)
for more information.

Example integration here in [Sealas](https://github.com/Brainsware/sealas)

## Installation

Add `authtoken` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:authtoken, "~> 0.3"}
  ]
end
```

## Configuration

At a minimum, you need to specify the key used to encrypt the tokens.

Configure it in the application environment for `authtoken` or
pass it as a parameter to `generate_token/2`.

```elixir
config :authtoken,
  token_key: <<1, 2, 3, 230, 103, 242, 149, 254, 4, 33, 137, 240, 23, 90, 99, 250>>
```

Generate a key with `generate_key/0`:

```elixir
iex> AuthToken.generate_key()
{:ok, <<1, 2, 3, 230, 103, 242, 149, 254, 4, 33, 137, 240, 23, 90, 99, 250>>}
```

The optional `timeout` environment key specifies how long tokens will be valid
before they expire, in seconds. The default is 86400 seconds, one day.
After it expires you need to generate a new one.

The optional `refresh` key specifies how often tokens can be used before they
should be refreshed, in seconds. The default is 1800 seconds, 30 minutes.

You can also pass a config map to functions with the same keys, letting
you have multiple JWTs in your application with different settings
or manage the config more flexibly.

## Usage

A common use case is to authenticate the user, then create a JWT token with the
user id. The app returns the token to the client in a cookie or in the response
to an API call. On subsequent requests, the client passes the token to the
server, which can get the information in the token.

Generate a token with `generate_token/2`:

```elixir
token_content = %{userid: user.id}

{:ok, token} = AuthToken.generate_token(token_content)
```

then pass it on to the user, e.g. in the view.

### Get the content / Decrypting

`decrypt_token/2` decrypts the token and returns the content you put in.
It accepts a token as input, or you can pass it a `t:Plug.Conn.t/0` and it will
pull the token from the `Authorization` HTTP header.

```elixir
{:ok, token} = AuthToken.decrypt_token(conn)

user_id = token.userid

```

It reads the key from the application environment by default, or you can pass
it in as a parameter.

```elixir
{:ok, token} = AuthToken.decrypt_token(token, %{token_key: key})
```

### Refreshing

Refreshing gives your app an opportunity to check the validity of the user
without forcing them to log in completely. It's a kind of "soft" expiration.

Call `refresh_token/2` passing either the token or decrypted result.
This will extend the lifetime of the token (`rt`) for the `refresh` period
until it expires completely. You can use this opportunity to check if the
user's credentials haven't been revoked in the meantime.

```elixir
case AuthToken.refresh_token(token) do
  {:error, :timedout} ->
    # Redirect to login
  {:error, :stillfresh} ->
    # Do nothing
  {:ok, token} ->
    # Check credentials and send back new token
end
```

### Plug

For verification you can use the plug `AuthToken.Plug.verify_token`.

```elixir
import AuthToken.Plug

pipeline :auth do
  plug :verify_token
end

scope "/protected/route", MyApp do
  pipe_through :auth

  resources "/", DoNastyStuffController
end
```

API documentation can be found in [hexdocs](https://hexdocs.pm/authtoken).
