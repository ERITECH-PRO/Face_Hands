## Face + Hands (Docker + Portainer)

### Démarrage rapide

1) Déployer la stack (`docker-compose.yml`) sur ton VPS (Portainer).
2) Ouvrir `http://31.97.177.87:8012/` (ou ton `PUBLIC_PORT`).
3) Sur VPS, définir `STREAM_URL` vers un flux RTSP/HTTP (pas `0`).

Pages utiles:

- UI stream: `/`
- Upload UI: `/upload`

### API pour stocker / récupérer des images

- **Lister**: `GET /api/images`
- **Récupérer**: `GET /api/images/<id>`
- **Uploader** (multipart): `POST /api/images` avec champ `file` (+ optionnel `person`)
- **Snapshot** (sauver la dernière frame du flux): `POST /api/snapshot`
- **Health**: `GET /api/health`

Les fichiers sont stockés sur disque dans `./data` (monté dans le conteneur).

#### Exemples `curl`

Uploader:

```bash
curl -F "person=Aziz" -F "file=@image.jpg" "http://31.97.177.87:8012/api/images"
```

Lister:

```bash
curl "http://31.97.177.87:8012/api/images"
```

Récupérer:

```bash
curl -o out.jpg "http://31.97.177.87:8012/api/images/<id>"
```

Snapshot (il faut que `/video.mjpeg` tourne et génère des frames):

```bash
curl -X POST "http://31.97.177.87:8012/api/snapshot"
```

### Sécurité

L’API est **sans token**. Pour sécuriser, le plus simple est:

- mettre le service derrière Nginx Proxy Manager (basic auth / IP allowlist)
- ou restreindre l’accès au port via firewall
