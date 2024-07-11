#!/usr/bin/env python
# encoding: utf-8
import socket
import threading
import select
import sys
import time
import argparse
import logging
from os import system

# Configuração do logger
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

system("clear")

# Argumentos de linha de comando
parser = argparse.ArgumentParser(description='Servidor Proxy SOCKS.')
parser.add_argument('--port', type=int, default=80, help='Porta para o servidor (default: 80)')
args = parser.parse_args()

# Configurações
IP = '0.0.0.0'
PORT = args.port
BUFLEN = 8196 * 8
TIMEOUT = 60
MSG = ''
COR = '<font color="null">'
FTAG = '</font>'
DEFAULT_HOST = '0.0.0.0:22'
RESPONSE = f"HTTP/1.1 200 {COR}{MSG}{FTAG}\r\n\r\n"

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        try:
            self.soc = socket.socket(socket.AF_INET)
            self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.soc.settimeout(2)
            self.soc.bind((self.host, self.port))
            self.soc.listen(0)
            self.running = True
            logger.info(f"Servidor iniciado em {self.host}:{self.port}")

            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                    conn = ConnectionHandler(c, self, addr)
                    conn.start()
                    self.addConn(conn)
                except socket.timeout:
                    continue
                except Exception as e:
                    logger.error(f"Erro ao aceitar conexão: {e}")
        finally:
            self.running = False
            self.soc.close()
            logger.info("Servidor encerrado")

    def addConn(self, conn):
        with self.threadsLock:
            if self.running:
                self.threads.append(conn)
                    
    def removeConn(self, conn):
        with self.threadsLock:
            self.threads.remove(conn)
                
    def close(self):
        self.running = False
        with self.threadsLock:
            for c in self.threads:
                c.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = ''
        self.server = server
        self.log = f'Conexao: {addr}'

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except Exception as e:
            logger.error(f"Erro ao fechar conexão do cliente: {e}")
        finally:
            self.clientClosed = True
            
        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except Exception as e:
            logger.error(f"Erro ao fechar conexão com o alvo: {e}")
        finally:
            self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            hostPort = self.findHeader(self.client_buffer, 'X-Real-Host')
            
            if hostPort == '':
                hostPort = DEFAULT_HOST

            split = self.findHeader(self.client_buffer, 'X-Split')

            if split != '':
                self.client.recv(BUFLEN)
            
            if hostPort != '':
                if hostPort.startswith(IP):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                logger.warning('No X-Real-Host header found')
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')
        except Exception as e:
            logger.error(f'Erro na conexão: {e}')
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        aux = head.find(f'{header}: ')
        if aux == -1:
            return ''
        aux = head.find(':', aux)
        head = head[aux+2:]
        aux = head.find('\r\n')
        return '' if aux == -1 else head[:aux]

    def connect_target(self, host):
        i = host.find(':')
        port = int(host[i+1:]) if i != -1 else (443 if self.method == 'CONNECT' else 22)
        host = host[:i] if i != -1 else host
        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(host, port)[0]
        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        self.log += f' - CONNECT {path}'
        self.connect_target(path)
        self.client.sendall(RESPONSE.encode('utf-8'))
        self.client_buffer = ''
        logger.info(self.log)
        self.doCONNECT()
                    
    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while True:
            count += 1
            recv, _, err = select.select(socs, [], socs, 3)
            if err:
                error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]
                            count = 0
                        else:
                            break
                    except Exception as e:
                        logger.error(f"Erro na transferência de dados: {e}")
                        error = True
                        break
            if count == TIMEOUT or error:
                break

def main(host=IP, port=PORT):
    print("\033[0;34m━"*8,"\033[1;32m PROXY SOCKS","\033[0;34m━"*8,"\n")
    print("\033[1;33mIP:\033[1;32m " + IP)
    print("\033[1;33mPORTA:\033[1;32m " + str(PORT) + "\n")
    print("\033[0;34m━"*10,"\033[1;32m TURBONET2023","\033[0;34m━\033[1;37m"*11,"\n")
    server = Server(IP, PORT)
    server.start()
    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        print('\nParando...')
        server.close()

if __name__ == '__main__':
    main()
