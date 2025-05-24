#!/usr/bin/env bash
#
# Simulação de funcionamento de fórum público
# para negociação de jogadores de futebol com o Freechains
# 

set -e

# Caminho para pasta de dados dos nós
BASE_DIR="$(pwd)"
DATA_DIR="$BASE_DIR/nodes"
mkdir -p "$DATA_DIR/node1" "$DATA_DIR/node2" "$DATA_DIR/node3" "$DATA_DIR/node4"

# Portas de cada nó
PORT1=4040
PORT2=4041
PORT3=4042
PORT4=4043

# Chain pública
CHAIN="#forum"

# Usuários
USERS=(Normal1 Normal2 Troll Newbie)

# Função para enviar cadeia para todos os pares
sendall(){
    ./freechains --host=localhost:$1 peer localhost:$PORT1 send $CHAIN
    ./freechains --host=localhost:$1 peer localhost:$PORT2 send $CHAIN
    ./freechains --host=localhost:$1 peer localhost:$PORT3 send $CHAIN
    ./freechains --host=localhost:$1 peer localhost:$PORT4 send $CHAIN
}

# Iniciando hosts
./freechains-host --port=$PORT1 start --data "$DATA_DIR/node1" --no-tui & HOST1_PID=$!
./freechains-host --port=$PORT2 start --data "$DATA_DIR/node2" --no-tui & HOST2_PID=$!
./freechains-host --port=$PORT3 start --data "$DATA_DIR/node3" --no-tui & HOST3_PID=$!
./freechains-host --port=$PORT4 start --data "$DATA_DIR/node4" --no-tui & HOST4_PID=$!

# Delay para os hosts subirem
sleep 2

# Definindo timestampo inicial
ts_start="2025-02-01 00:00:00 UTC"
TS_START=$(date -d "$ts_start" +%s)
for port in $PORT1 $PORT2 $PORT3 $PORT4; do
  ./freechains-host now $TS_START --port=$port
done

# Gerar chave dos usuários e armazenar em arquivos
KEYS_DIR="$BASE_DIR/keys"
mkdir -p "$KEYS_DIR"
for user in "${USERS[@]}"; do
  read PUBLIC_KEY PRIVATE_KEY < <(./freechains --host=localhost:$PORT1 keys pubpvt "$user")

    echo "$PUBLIC_KEY" > "$KEYS_DIR/${user}_public.key"
    echo "$PRIVATE_KEY" > "$KEYS_DIR/${user}_private.key"
    chmod 600 "$KEYS_DIR/${user}_private.key"
done

# Criando a cadeia e fazendo join
./freechains --host=localhost:$PORT1 chains join $CHAIN "$(< keys/Normal1_public.key)"
./freechains --host=localhost:$PORT2 chains join $CHAIN "$(< keys/Normal1_public.key)"
./freechains --host=localhost:$PORT3 chains join $CHAIN "$(< keys/Normal1_public.key)"
./freechains --host=localhost:$PORT4 chains join $CHAIN "$(< keys/Normal1_public.key)"

# Inicio da simulação 

# Normal1 posta oferta através do nó1
./freechains --host=localhost:$PORT1 chain $CHAIN post inline "Posição: Meia / Precisão de passes: 91% / Desarmes: 12 / Status: Aberta" --sing="$(< keys/Normal1_private.key)"
sendall $PORT1

# Normal2 da like na oferta de Normal1 através do nó2
read HEAD < <(./freechains --host=localhost:$PORT2 chain $CHAIN heads)
echo "$HEAD" > "$BASE_DIR/blocos.txt"
./freechains --host=localhost:$PORT2 chain $CHAIN like "$(< blocos.txt)" --sign="$(< keys/Normal2_private.key)"
sendall $PORT2

# Troll posta provocação através do nó3
./freechains --host=localhost:$PORT3 chain $CHAIN post inline "Que jogador fraco!" --sing="$(< keys/Troll_private.key)"
sendall $PORT3

# Avançar 10 dias
TS_MONTH1=$(($TS_START + 10*24*3600))
for port in $PORT1 $PORT2 $PORT3 $PORT4; do
  ./freechains-host now $TS_MONTH1 --port=$port
done

# Newbie faz pergunta através do nó4
./freechains --host=localhost:$PORT4 chain $CHAIN post inline "Como encontrar ofertas?" --sing="$(< keys/Newbie_private.key)"
sendall $PORT4

# Normal2 aceita oferta através do nó2
./freechains --host=localhost:$PORT2 chain $CHAIN post inline "Normal1, vou querer o jogador" --sing="$(< keys/Normal2_private.key)"
sendall $PORT2

# Normal1 encerra oferta através do nó1
./freechains --host=localhost:$PORT1 chain $CHAIN post inline "Posição: Meia / Precisão de passes: 91% / Desarmes: 12 / Status: Fechada" --sing="$(< keys/Normal1_private.key)"
sendall $PORT1

# Avançar 30 dias
TS_MONTH2=$(($TS_START + 40*24*3600))
for port in $PORT1 $PORT2 $PORT3 $PORT4; do
  ./freechains-host now $TS_MONTH2 --port=$port
done

# Troll posta oferta falsa através do nó3
./freechains --host=localhost:$PORT3 chain $CHAIN post inline "Posição: Goleiro / Altura: 2,87m / Status: Aberta" --sing="$(< keys/Troll_private.key)"
sendall $PORT3

# Normal1 da dislike na oferta de Troll através do nó2
read HEAD < <(./freechains --host=localhost:$PORT1 chain $CHAIN heads)
echo "$HEAD" > "$BASE_DIR/blocos.txt"
./freechains --host=localhost:$PORT1 chain $CHAIN dislike "$(< blocos.txt)" --sign="$(< keys/Normal1_private.key)"
sendall $PORT1

# Normal2 da dislike na oferta de Troll através do nó2
./freechains --host=localhost:$PORT2 chain $CHAIN dislike "$(< blocos.txt)" --sign="$(< keys/Normal2_private.key)"
sendall $PORT2

# Avançar 30 dias
TS_MONTH3=$(($TS_START + 70*24*3600))
for port in $PORT1 $PORT2 $PORT3 $PORT4; do
  ./freechains-host now $TS_MONTH3 --port=$port
done

# Normal2 posta oferta através do nó2
./freechains --host=localhost:$PORT2 chain $CHAIN post inline "Posição: Atacante / Gols: 37 / Status aberta" --sing="$(< keys/Normal2_private.key)"
sendall $PORT2

echo "=== FIM ==="