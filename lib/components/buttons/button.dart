CustomButton(
  text: isLoading ? "Entrando..." : "Entrar",
  onPressed: isLoading ? null : handleLogin,
  variant: ButtonVariant.poliedro, // ðŸŒˆ gradiente igual ao fundo
  size: ButtonSize.lg,
)
